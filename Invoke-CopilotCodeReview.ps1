function Invoke-CopilotCodeReview {
    param (
        [Parameter(Mandatory)]
        [string]$SourceBranch,

        [Parameter(Mandatory)]
        [string]$TargetBranch,

        [Parameter(Mandatory)]
        [string]$PathToReviewFile,

        [Parameter(Mandatory)]
        [string]$GitHubToken,

        [Parameter()]
        [string]$RepoPath
    )

    # Set COPILOT_GITHUB_TOKEN for Copilot CLI auth
    $env:COPILOT_GITHUB_TOKEN = $GitHubToken

    # Verify Copilot CLI available
    $copilotCmd = Get-Command copilot -ErrorAction SilentlyContinue
    if (-not $copilotCmd) {
        Write-Host "Copilot CLI not found. Installing via official script..."
        bash -c 'curl -fsSL https://gh.io/copilot-install | bash'

        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Process")
        $copilotCmd = Get-Command copilot -ErrorAction SilentlyContinue
        if (-not $copilotCmd) {
            throw "Copilot CLI installation failed. Ensure curl and bash are available."
        }
    }

    Write-Host "Using Copilot CLI: $(copilot --version)"

    # Get code changes
    $codeChangeParams = @{
        SourceBranch = $SourceBranch
        TargetBranch = $TargetBranch
    }
    if ($RepoPath) { $codeChangeParams['RepoPath'] = $RepoPath }
    [string]$changes = Get-CodeChanges @codeChangeParams | Out-String
    Write-Host "Code changes to review:`n$changes"

    # Build combined prompt: system instructions + code changes
    if (-not (Test-Path -LiteralPath $PathToReviewFile)) {
        throw "Review prompt file not found: $PathToReviewFile"
    }
    $systemPrompt = Get-Content -LiteralPath $PathToReviewFile -Raw

    $fullPrompt = @"
$systemPrompt

---

$changes
"@

    try {
        Write-Host "Sending code changes to Copilot CLI (claude-sonnet-4.6) for review..."

        # For large prompts, write to temp file and pipe to Copilot CLI
        $tempFile = New-TemporaryFile
        $fullPrompt | Out-File -LiteralPath $tempFile.FullName -Encoding UTF8 -NoNewline
        $result = Get-Content -LiteralPath $tempFile.FullName -Raw | copilot --model claude-sonnet-4.6

        if ($LASTEXITCODE -ne 0) {
            throw "Copilot CLI failed with exit code $LASTEXITCODE. Output: $result"
        }

        Remove-Item -LiteralPath $tempFile.FullName -Force -ErrorAction SilentlyContinue

        # CLI returns array of lines — join to single string
        $result = ($result | Out-String).Trim()

        # Strip non-JSON wrapping (markdown fences, etc.) — extract first { to last }
        $startIdx = $result.IndexOf('{')
        $endIdx   = $result.LastIndexOf('}')
        if ($startIdx -ge 0 -and $endIdx -gt $startIdx) {
            $result = $result.Substring($startIdx, $endIdx - $startIdx + 1)
        }

        Write-Host "Copilot CLI review response:"
        Write-Host $result

        return $result
    }
    finally {
    }
}
