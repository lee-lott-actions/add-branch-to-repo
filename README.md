# Add Branch Action

This GitHub Action adds a specified branch to a repository using the GitHub API. It retrieves the default branch's latest commit SHA and creates the new branch, returning a result indicating success or failure and an error message if the operation fails.

## Features
- Creates a specified branch in a repository via the GitHub API.
- Outputs a result (`success` or `failure`) and an error message for easy integration into workflows.
- Requires a GitHub token with `repo` scope for branch creation.

## Inputs
| Name         | Description                                      | Required | Default |
|--------------|--------------------------------------------------|----------|---------|
| `repo-name`  | The name of the repository to add the branch to. | Yes      | N/A     |
| `owner`      | The owner of the repository (user or organization). | Yes      | N/A     |
| `token`      | GitHub token with repository write access.       | Yes      | N/A     |
| `branch-name`| The name of the branch to create.                | Yes      | N/A     |

## Outputs
| Name           | Description                                           |
|----------------|-------------------------------------------------------|
| `result`       | Result of the branch creation (`success` for HTTP 201, `failure` otherwise). |
| `error-message`| Error message if the branch creation fails.           |

## Usage
1. **Add the Action to Your Workflow**:
   Create or update a workflow file (e.g., `.github/workflows/add-branch.yml`) in your repository.

2. **Reference the Action**:
   Use the action by referencing the repository and version (e.g., `v1`), or the local path if stored in the same repository.

3. **Example Workflow**:
   ```yaml
   name: Add Branch
   on:
     push:
       branches:
         - main
   jobs:
     add-branch:
       runs-on: ubuntu-latest
       steps:
         - name: Add Branch
           id: add
           uses: lee-lott-actions/add-branch-to-repo@v1.0.0
           with:
             repo-name: 'my-repo'
             owner: ${{ github.repository_owner }}
             token: ${{ secrets.GITHUB_TOKEN }}
             branch-name: 'development'
         - name: Check Result
           run: |
             if [[ "${{ steps.add.outputs.result }}" == "success" ]]; then
               echo "Branch created successfully."
             else
               echo "${{ steps.add.outputs.error-message }}"
               exit 1
             fi
