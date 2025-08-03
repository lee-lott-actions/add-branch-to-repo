#!/bin/bash
add_branch() {
  local repo_name="$1"
  local owner="$2"
  local token="$3"
  local branch_name="$4"

  # Validate required inputs
  if [ -z "$repo_name" ] || [ -z "$branch_name" ] || [ -z "$owner" ] || [ -z "$token" ]; then
      echo "Error: Missing required parameters"
      echo "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided." >> "$GITHUB_OUTPUT"
      echo "result=failure" >> "$GITHUB_OUTPUT"
      return
  fi

  echo "Creating branch $branch_name for repository $owner/$repo_name"

  # Use MOCK_API if set, otherwise default to GitHub API
  local api_base_url="${MOCK_API:-https://api.github.com}"
  
  # Fetch default branch
  DEFAULT_BRANCH_RESPONSE=$(curl -s -w "%{http_code}" -o default_branch.json \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    "$api_base_url/repos/$owner/$repo_name")
    
  DEFAULT_BRANCH_STATUS=$(echo "$DEFAULT_BRANCH_RESPONSE" | tail -n1)  
  if [ "$DEFAULT_BRANCH_STATUS" -ne 200 ]; then
    echo "result=failure" >> "$GITHUB_OUTPUT"
    echo "error-message=Failed to fetch default branch for $repo_name. Status: $DEFAULT_BRANCH_STATUS" >> "$GITHUB_OUTPUT"
    echo "Error: Failed to fetch default branch. Status: $DEFAULT_BRANCH_STATUS"
    rm -f default_branch.json
    return
  fi
  
  DEFAULT_BRANCH=$(jq -r .default_branch default_branch.json)
  rm -f default_branch.json
  
  # Fetch SHA of default branch
  SHA_RESPONSE=$(curl -s -w "%{http_code}" -o sha.json \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    $api_base_url/repos/$owner/$repo_name/branches/$DEFAULT_BRANCH)
    
  SHA_STATUS=$(echo "$SHA_RESPONSE" | tail -n1)
  if [ "$SHA_STATUS" -ne 200 ]; then
    echo "result=failure" >> "$GITHUB_OUTPUT"
    echo "error-message=Failed to fetch SHA for branch $DEFAULT_BRANCH in $repo_name. Status: $SHA_STATUS" >> "$GITHUB_OUTPUT"
    echo "Error: Failed to fetch SHA. Status: $SHA_STATUS"
    rm -f sha.json
    return
  fi
  
  SHA=$(jq -r .commit.sha sha.json)
  rm -f sha.json
  
  # Create specified branch
  CREATE_RESPONSE=$(curl -s -w "%{http_code}" -o create_response.json \
    -X POST \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    $api_base_url/repos/$owner/$repo_name/git/refs \
    -d "{\"ref\": \"refs/heads/$branch_name\", \"sha\": \"$SHA\"}")
    
  CREATE_STATUS=$(echo "$CREATE_RESPONSE" | tail -n1)
  if [ "$CREATE_STATUS" -ne 201 ]; then
    echo "result=failure" >> "$GITHUB_OUTPUT"
    echo "error-message=Failed to create branch $branch_name: $(jq -r .message create_response.json)" >> "$GITHUB_OUTPUT"
    echo "Error: Failed to create branch $branch_name: $(jq -r .message create_response.json)"
    rm -f create_response.json
    return
  fi
  
  echo "result=success" >> "$GITHUB_OUTPUT"
  echo "Successfully created branch $branch_name in $repo_name"
  rm -f create_response.json
}
