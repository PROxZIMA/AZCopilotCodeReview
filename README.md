# Azure DevOps PR Code Review with GitHub Copilot

Automated code review pipeline for Azure DevOps pull requests using GitHub Copilot.

## How It Works

1. Pipeline triggers on PR creation/update
2. `Get-CodeChanges.ps1` extracts git diff between source and target branches
3. `Invoke-CopilotCodeReview.ps1` sends changes to GitHub Copilot for structured review
4. `Set-PullRequestComments.ps1` posts review comments as PR threads in Azure DevOps

## Prerequisites

- **Azure DevOps PAT** with permissions: `Code: Read`, `Pull Request Threads: Read & Write`
- **GitHub PAT** with Copilot access

## Setup

1. Add two secret pipeline variables:
   - `AZURE_DEVOPS_PAT` — your Azure DevOps PAT
   - `GITHUB_TOKEN` — your GitHub PAT with Copilot access
2. Create a build validation policy on target branch pointing to `azure-pipeline.yml`
3. Customize `Generic.codereviewprompt.md` for your review rules. Currently tailored for C# and TypeScript.

## Supports
- [x] C# and TypeScript code changes
- [x] Inline code comments with Copilot suggestions
- [x] Pull request comment threading to group related comments
- [x] Minimal git diff context to stay within token limits
- [x] Simple configuration with Manual Trigger for Specific PR & Build Validation Trigger (no IT approval for ADO extensions)
- [x] Supports larger PRs code context

## Todo
- [ ] Support Azure DevOps pipeline's built-in System Access Token
- [ ] Improve pull request comment threading logic to group related comments
- [ ] Improve auto-fix suggestions from Copilot
- [ ] Fetch and include linked work item details, commit/PR name and description as review context
- [ ] Improve code review prompt to include more context (I'm not a Copilot prompt engineering expert, haha)
- [ ] Add support for Github Copilot model selection (e.g. `gpt-4-codex` vs `gpt-3.5-codex`)
- [ ] Add support for more languages (Python, Java, etc.)

## References
- [ado-copilot-code-review](https://github.com/little-fort/ado-copilot-code-review)
- [azure-devops-code-review-scripts](https://github.com/johnlokerse/azure-devops-code-review-scripts)
