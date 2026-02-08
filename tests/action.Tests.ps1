BeforeAll {
	$script:RepoName    = "test-repo"
	$script:Owner       = "test-owner"
	$script:Token       = "fake-token"
	$script:BranchName  = "new-branch"

	. "$PSScriptRoot/../action.ps1"
}

Describe "Add-Branch" {
	BeforeEach {
		$env:GITHUB_OUTPUT = [System.IO.Path]::GetTempFileName()
	}

	AfterEach {
		if (Test-Path $env:GITHUB_OUTPUT) {
			Remove-Item $env:GITHUB_OUTPUT -Force
		}
	}

	Context "Success path" {
		It "succeeds with HTTP 201" {
			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo$' } {
				[PSCustomObject]@{
					StatusCode = 200
					Content    = '{"default_branch":"main"}'
				}
			}

			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo/branches/main$' } {
				[PSCustomObject]@{
					StatusCode = 200
					Content    = '{"commit":{"sha":"abc123"}}'
				}
			}

			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'POST' -and $Uri -match '/repos/test-owner/test-repo/git/refs$' } {
				[PSCustomObject]@{
					StatusCode = 201
					Content    = '{"ref":"refs/heads/new-branch"}'
				}
			}

			Add-Branch -RepoName $RepoName -Owner $Owner -Token $Token -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=success"
		}
	}

	Context "Input validation" {
		It "fails with empty repo_name" {
			Add-Branch -RepoName "" -Owner $Owner -Token $Token -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Should -Contain "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided."
		}

		It "fails with empty owner" {
			Add-Branch -RepoName $RepoName -Owner "" -Token $Token -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Should -Contain "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided."
		}

		It "fails with empty token" {
			Add-Branch -RepoName $RepoName -Owner $Owner -Token "" -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Should -Contain "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided."
		}

		It "fails with empty branch_name" {
			Add-Branch -RepoName $RepoName -Owner $Owner -Token $Token -BranchName ""

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Should -Contain "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided."
		}
	}

	Context "Fetch default branch (GET /repos/{owner}/{repo})" {
		It "fails to fetch default branch with HTTP 404" {
			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo$' } {
				[PSCustomObject]@{
					StatusCode = 404
					Content    = '{"message":"Repository not found"}'
				}
			}

			Add-Branch -RepoName $RepoName -Owner $Owner -Token $Token -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Should -Contain "error-message=Error: Failed to fetch default branch for test-repo. Status: 404"
		}

		It "fails when default branch cannot be parsed from repo response (default_branch missing/null)" {
			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo$' } {
				[PSCustomObject]@{
					StatusCode = 200
					Content    = '{"id":123,"name":"test-repo"}'
				}
			}

			Add-Branch -RepoName $RepoName -Owner $Owner -Token $Token -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Should -Contain "error-message=Error: Could not parse default branch from response."
		}

		It "writes result=failure and error-message on exception (catch block)" {
			Mock Invoke-WebRequest { throw "API Error" }

			Add-Branch -RepoName $RepoName -Owner $Owner -Token $Token -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			($output | Where-Object { $_ -match "^error-message=Error: Failed to fetch default branch for test-repo\. Exception:" }) |
				Should -Not -BeNullOrEmpty
		}
	}

	Context "Fetch SHA (GET /repos/{owner}/{repo}/branches/{defaultBranch})" {
		It "fails to fetch SHA with HTTP 404" {
			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo$' } {
				[PSCustomObject]@{
					StatusCode = 200
					Content    = '{"default_branch":"main"}'
				}
			}

			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo/branches/main$' } {
				[PSCustomObject]@{
					StatusCode = 404
					Content    = '{"message":"Branch not found"}'
				}
			}

			Add-Branch -RepoName $RepoName -Owner $Owner -Token $Token -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Should -Contain "error-message=Error: Failed to fetch SHA for branch main in test-repo. Status: 404"
		}

		It "fails when commit SHA cannot be parsed from branch response (commit.sha missing/null)" {
			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo$' } {
				[PSCustomObject]@{
					StatusCode = 200
					Content    = '{"default_branch":"main"}'
				}
			}

			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo/branches/main$' } {
				[PSCustomObject]@{
					StatusCode = 200
					Content    = '{"commit":{}}'
				}
			}

			Add-Branch -RepoName $RepoName -Owner $Owner -Token $Token -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Should -Contain "error-message=Error: Could not parse commit.sha from response."
		}

		It "writes result=failure and error-message when fetching SHA throws (catch block)" {
			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo$' } {
				[PSCustomObject]@{
					StatusCode = 200
					Content    = '{"default_branch":"main"}'
				}
			}

			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo/branches/main$' } {
				throw [System.Exception]::new("SHA API Error")
			}

			Add-Branch -RepoName $RepoName -Owner $Owner -Token $Token -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			($output | Where-Object { $_ -match "^error-message=Error: Failed to fetch SHA for branch main in test-repo\. Exception: SHA API Error$" }) |
				Should -Not -BeNullOrEmpty
		}
	}

	Context "Create ref (POST /repos/{owner}/{repo}/git/refs)" {
		It "fails to create branch with HTTP 422" {
			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo$' } {
				[PSCustomObject]@{
					StatusCode = 200
					Content    = '{"default_branch":"main"}'
				}
			}

			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo/branches/main$' } {
				[PSCustomObject]@{
					StatusCode = 200
					Content    = '{"commit":{"sha":"abc123"}}'
				}
			}

			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'POST' -and $Uri -match '/repos/test-owner/test-repo/git/refs$' } {
				[PSCustomObject]@{
					StatusCode = 422
					Content    = '{"message":"Reference already exists"}'
				}
			}

			Add-Branch -RepoName $RepoName -Owner $Owner -Token $Token -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Should -Contain "error-message=Error: Failed to create branch new-branch: Reference already exists"
		}

		It "writes result=failure and error-message when create branch throws (catch block)" {
			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo$' } {
				[PSCustomObject]@{
					StatusCode = 200
					Content    = '{"default_branch":"main"}'
				}
			}

			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'GET' -and $Uri -match '/repos/test-owner/test-repo/branches/main$' } {
				[PSCustomObject]@{
					StatusCode = 200
					Content    = '{"commit":{"sha":"abc123"}}'
				}
			}

			Mock Invoke-WebRequest -ParameterFilter { $Method -eq 'POST' -and $Uri -match '/repos/test-owner/test-repo/git/refs$' } {
				throw [System.Exception]::new("Create API Error")
			}

			Add-Branch -RepoName $RepoName -Owner $Owner -Token $Token -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			($output | Where-Object { $_ -match "^error-message=Error: Failed to create branch new-branch\. Exception: Create API Error$" }) |
				Should -Not -BeNullOrEmpty
		}
	}
}