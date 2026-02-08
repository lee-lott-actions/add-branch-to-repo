function Add-Branch {
	param(
		[string]$RepoName,
		[string]$Owner,
		[string]$Token,
		[string]$BranchName
	)

	# Validate required inputs
	if ([string]::IsNullOrEmpty($RepoName) -or
		[string]::IsNullOrEmpty($BranchName) -or
		[string]::IsNullOrEmpty($Owner) -or
		[string]::IsNullOrEmpty($Token)) {

		Write-Host "Error: Missing required parameters"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided."
		Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
		return
	}

	Write-Host "Creating branch $BranchName for repository $Owner/$RepoName"

	# Use MOCK_API if set, otherwise default to GitHub API
	$apiBaseUrl = $env:MOCK_API
	if (-not $apiBaseUrl) { $apiBaseUrl = "https://api.github.com" }

	$headers = @{
		Authorization  = "Bearer $Token"
		Accept         = "application/vnd.github.v3+json"
		"Content-Type" = "application/json"
		"User-Agent"   = "pwsh-action"
	}

	# 1) Fetch default branch
	$repoUri = "$apiBaseUrl/repos/$Owner/$RepoName"
	try {
		$repoResponse = Invoke-WebRequest -Uri $repoUri -Method Get -Headers $headers
	}
	catch {
		$errorMsg = "Error: Failed to fetch default branch for $RepoName. Exception: $($_.Exception.Message)"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
		Write-Host $errorMsg
		return
	}

	if ($repoResponse.StatusCode -ne 200) {
		$errorMsg = "Error: Failed to fetch default branch for $RepoName. Status: $($repoResponse.StatusCode)"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
		Write-Host $errorMsg
		return
	}

	$defaultBranch = $null
	try {
		$repoObj = $repoResponse.Content | ConvertFrom-Json
		$defaultBranch = $repoObj.default_branch
	} catch {
		$defaultBranch = $null
	}

	if ([string]::IsNullOrEmpty($defaultBranch)) {
		$errorMsg = "Error: Could not parse default branch from response."
		Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
		Write-Host $errorMsg
		return
	}

	# 2) Fetch SHA of default branch
	$branchUri = "$apiBaseUrl/repos/$Owner/$RepoName/branches/$defaultBranch"
	try {
		$shaResponse = Invoke-WebRequest -Uri $branchUri -Method Get -Headers $headers
	}
	catch {
		$errorMsg = "Error: Failed to fetch SHA for branch $defaultBranch in $RepoName. Exception: $($_.Exception.Message)"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
		Write-Host $errorMsg
		return
	}

	if ($shaResponse.StatusCode -ne 200) {
		$errorMsg = "Error: Failed to fetch SHA for branch $defaultBranch in $RepoName. Status: $($shaResponse.StatusCode)"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
		Write-Host $errorMsg
		return
	}

	$sha = $null
	try {
		$shaObj = $shaResponse.Content | ConvertFrom-Json
		$sha = $shaObj.commit.sha
	} catch {
		$sha = $null
	}

	if ([string]::IsNullOrEmpty($sha)) {
		$errorMsg = "Error: Could not parse commit.sha from response."
		Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
		Write-Host $errorMsg
		return
	}

	# 3) Create specified branch
	$createUri = "$apiBaseUrl/repos/$Owner/$RepoName/git/refs"
	$body = @{
		ref = "refs/heads/$BranchName"
		sha = $sha
	} | ConvertTo-Json -Compress

	try {
		$createResponse = Invoke-WebRequest -Uri $createUri -Method Post -Headers $headers -Body $body
	}
	catch {
		$errorMsg = "Error: Failed to create branch $BranchName. Exception: $($_.Exception.Message)"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
		Write-Host $errorMsg
		return
	}

	if ($createResponse.StatusCode -ne 201) {
		$message = $null
		try {
			if (-not [string]::IsNullOrEmpty($createResponse.Content)) {
				$message = ( $createResponse.Content | ConvertFrom-Json ).message
			}
		} catch {
			$message = $null
		}

		if ([string]::IsNullOrEmpty($message)) { $message = "Unknown error" }

		$errorMsg = "Error: Failed to create branch $BranchName: $message"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "result=failure"
		Add-Content -Path $env:GITHUB_OUTPUT -Value "error-message=$errorMsg"
		Write-Host $errorMsg
		return
	}

	Add-Content -Path $env:GITHUB_OUTPUT -Value "result=success"
	Write-Host "Successfully created branch $BranchName in $RepoName"
}