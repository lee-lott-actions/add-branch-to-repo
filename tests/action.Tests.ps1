Describe "Add-Branch" {
	BeforeAll {
		$script:RepoName    = "test-repo"
		$script:Owner       = "test-owner"
		$script:Token       = "fake-token"
		$script:BranchName  = "new-branch"
        $script:MockApiUrl  = "http://127.0.0.1:3000"	
		. "$PSScriptRoot/../action.ps1"
	}
	
	BeforeEach {
        $env:GITHUB_OUTPUT = New-TemporaryFile
        $env:MOCK_API = $script:MockApiUrl
    }
	
    AfterEach {
        if (Test-Path $env:GITHUB_OUTPUT) { Remove-Item $env:GITHUB_OUTPUT }
        Remove-Item Env:MOCK_API -ErrorAction SilentlyContinue
    }

	Context "Success Cases" {
		It "unit: Add-Branch succeeds with HTTP 201" {
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

	Context "Failure Cases" {
		Context "Fetch Default Branch Failures" {
			It "unit: Add-Branch fails to fetch default branch with HTTP 404" {
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
	
			It "unit: Add-Branch fails when default branch cannot be parsed from repo response" {
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
	
			It "unit: Add-Branch fails when fetching default branch throws exception" {
				Mock Invoke-WebRequest { throw "API Error" }
	
				Add-Branch -RepoName $RepoName -Owner $Owner -Token $Token -BranchName $BranchName
	
				$output = Get-Content $env:GITHUB_OUTPUT
				$output | Should -Contain "result=failure"
				($output | Where-Object { $_ -match "^error-message=Error: Failed to fetch default branch for test-repo\. Exception:" }) |
					Should -Not -BeNullOrEmpty
			}
		}
		
		Context "Fetch SHA Failures" {
			It "unit: Add-Branch fails to fetch SHA with HTTP 404" {
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
	
			It "unit: Add-Branch fails when commit SHA cannot be parsed from branch response (commit.sha missing/null)" {
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
	
			It "unit: Add-Branch fails when fetching SHA throws exception" {
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

		Context "Create Ref Failures" {
			It "unit: Add-Branch fails to create branch with HTTP 422" {
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
	
			It "unit: Add-Branch fails when create branch throws exception" {
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

	Context "Parameter Validation Failure Cases" {
		It "unit: Add-Branch fails with empty RepoName" {
			Add-Branch -RepoName "" -Owner $Owner -Token $Token -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Should -Contain "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided."
		}

		It "unit: Add-Branch fails with empty Owner" {
			Add-Branch -RepoName $RepoName -Owner "" -Token $Token -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Should -Contain "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided."
		}

		It "unit: Add-Branch fails with empty Token" {
			Add-Branch -RepoName $RepoName -Owner $Owner -Token "" -BranchName $BranchName

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Should -Contain "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided."
		}

		It "unit: Add-Branch fails with empty BranchName" {
			Add-Branch -RepoName $RepoName -Owner $Owner -Token $Token -BranchName ""

			$output = Get-Content $env:GITHUB_OUTPUT
			$output | Should -Contain "result=failure"
			$output | Should -Contain "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided."
		}
	}	
}
