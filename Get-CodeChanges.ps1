function Get-CodeChanges {
    param (
        [string]$TargetBranch,
        [string]$SourceBranch,
        [string]$RepoPath
    )

    # Switch to repo directory if provided
    if ($RepoPath) {
        Write-Host "Switching to repo directory: $RepoPath"
        Push-Location $RepoPath
    }

    try {
        $renamedSourceBranch = $SourceBranch -replace 'refs/heads/', 'origin/'
        $renamedTargetBranch = $TargetBranch -replace 'refs/heads/', 'origin/'

        # Get changed code files only
        $changedFiles = git diff --name-only --diff-filter=AM "$renamedTargetBranch...$renamedSourceBranch"

        if ($LASTEXITCODE -ne 0) { throw "git diff failed with exit code $LASTEXITCODE. Verify branch names: '$renamedTargetBranch' and '$renamedSourceBranch'" }

        if (-not $changedFiles) { Write-Warning "No changed files detected between $renamedTargetBranch and $renamedSourceBranch"; return "" }

        # Add legend for diff markers
        $llmOutput = @"
# Code Review - Changes from $renamedSourceBranch to $renamedTargetBranch

## Legend:
- `+` = Added lines (new code)
- `-` = Removed lines (deleted code)
- `  ` = Unchanged lines (context)

---

"@

        foreach ($file in $changedFiles) {
            Write-Host "Processing: $file"

            # Ensure file path starts with / for full path from repository root
            $fullPath = if ($file.StartsWith('/')) { $file } else { "/$file" }

            # Get the unified diff with more context
            $diffLines = git diff "$renamedTargetBranch...$renamedSourceBranch" --unified=10 -- $file

            if ($LASTEXITCODE -ne 0) {
                Write-Warning "git diff failed for file '$file' (exit $LASTEXITCODE) — skipping."
                continue
            }

            $llmOutput += "## File: $fullPath`n`n"

            # Parse the diff output line by line
            $inHunk = $false
            $oldLineNum = 0
            $newLineNum = 0
            $hunkContent = @()
            $addedLines = 0
            $removedLines = 0

            foreach ($line in $diffLines) {
                # Check for hunk header
                if ($line -match '^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@') {
                    # If we were processing a previous hunk, output it
                    if ($hunkContent.Count -gt 0) {
                        $llmOutput += "### Changes: +$addedLines lines, -$removedLines lines`n"
                        $llmOutput += ($hunkContent -join "`n")
                        $llmOutput += "`n`n"
                    }

                    # Reset for new hunk
                    $hunkContent = @()
                    $addedLines = 0
                    $removedLines = 0
                    $inHunk = $true
                    $oldLineNum = [int]$matches[1]
                    $newLineNum = [int]$matches[3]
                    continue
                }

                # Skip file headers
                if ($line -match '^(diff --git|index|\+\+\+|---|\\ No newline)' -or $line.StartsWith('Binary file')) {
                    continue
                }

                # Process hunk content
                if ($inHunk) {
                    if ($line.StartsWith('+')) {
                        # Added line
                        $hunkContent += "{0,4}+ {1}" -f $newLineNum, $line.Substring(1)
                        $newLineNum++
                        $addedLines++
                    }
                    elseif ($line.StartsWith('-')) {
                        # Removed line
                        $hunkContent += "{0,4}- {1}" -f $oldLineNum, $line.Substring(1)
                        $oldLineNum++
                        $removedLines++
                    }
                    elseif ($line.StartsWith(' ')) {
                        # Context line (unchanged)
                        $hunkContent += "{0,4}  {1}" -f $newLineNum, $line.Substring(1)
                        $oldLineNum++
                        $newLineNum++
                    }
                    else {
                        # End of hunk
                        $inHunk = $false
                    }
                }
            }

            # Output the last hunk if any
            if ($hunkContent.Count -gt 0) {
                $llmOutput += "### Changes: +$addedLines lines, -$removedLines lines`n"
                $llmOutput += ($hunkContent -join "`n")
                $llmOutput += "`n"
            }
            $llmOutput += "`n---`n"
        }

        return $llmOutput
    }
    finally {
        if ($RepoPath) { Pop-Location }
    }
}
