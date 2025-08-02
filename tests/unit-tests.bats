#!/usr/bin/env bats

# Load the Bash script containing the add_branch function
load ../action.sh

# Mock the curl command to simulate API responses
mock_curl() {
  local http_code=$1
  local response_file=$2
  local output_file

  # Determine the output file from the curl command
  if echo "${*}" | grep -q -- '-o[[:space:]]\+default_branch.json'; then
    output_file="default_branch.json"
  elif echo "${*}" | grep -q -- '-o[[:space:]]\+sha.json'; then
    output_file="sha.json"
  elif echo "${*}" | grep -q -- '-o[[:space:]]\+create_response.json'; then
    output_file="create_response.json"
  else
    output_file="response.json"
  fi

  # Copy the mock response to the specified output file
  cat "$response_file" > "$output_file"
  # Return the HTTP status code and response to mimic curl -s -w "%{http_code}"
  echo -e "$(cat "$response_file")\n$http_code"
}

# Mock the jq command to simulate JSON parsing
mock_jq() {
  local field=$1
  local file=$2
  if [ "$field" = ".default_branch" ]; then
    echo "main"
  elif [ "$field" = ".commit.sha" ]; then
    echo "abc123"
  elif [ "$field" = ".message" ]; then
    cat "$file" | grep -oP '(?<="message": ")[^"]*'
  fi
}

# Setup function to run before each test
setup() {
  export GITHUB_OUTPUT=$(mktemp)
}

# Teardown function to clean up after each test
teardown() {
  cat "$GITHUB_OUTPUT"
  ls -l
  rm -f response.json default_branch.json sha.json create_response.json "$GITHUB_OUTPUT" mock_response.json mock_default_branch.json mock_sha.json mock_create_response.json
}

@test "add_branch succeeds with HTTP 201" {
  echo '{"default_branch": "main"}' > mock_default_branch.json
  echo '{"commit": {"sha": "abc123"}}' > mock_sha.json
  echo '{"ref": "refs/heads/new-branch"}' > mock_create_response.json

  curl() {
    if echo "${*}" | grep -q -- '-o[[:space:]]\+default_branch.json'; then
      mock_curl "200" mock_default_branch.json "${*}"
    elif echo "${*}" | grep -q -- '-o[[:space:]]\+sha.json'; then
      mock_curl "200" mock_sha.json "${*}"
    elif echo "${*}" | grep -q -- '-o[[:space:]]\+create_response.json'; then
      mock_curl "201" mock_create_response.json "${*}"
    fi
  }
  export -f curl

  jq() { 
    local flag="$1"
    local field="$2"
    local file="$3"

    if [ "$flag" = "-r" ]; then
      mock_jq "$field" "$file"
    else
      mock_jq "$flag" "$field"
    fi
  }
  export -f jq

  run add_branch "test-repo" "test-owner" "fake-token" "new-branch"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" == "result=success" ]
}

@test "add_branch fails to fetch default branch with HTTP 404" {
  echo '{"message": "Repository not found"}' > mock_response.json

  curl() {
    if echo "${*}" | grep -q -- '-o[[:space:]]\+default_branch.json'; then
      mock_curl "404" mock_response.json "${*}"
    fi
  }
  export -f curl

  jq() { 
    local flag="$1"
    local field="$2"
    local file="$3"

    if [ "$flag" = "-r" ]; then
      mock_jq "$field" "$file"
    else
      mock_jq "$flag" "$field"
    fi
  }
  export -f jq

  run add_branch "test-repo" "test-owner" "fake-token" "new-branch"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" == "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" == "error-message=Failed to fetch default branch for test-repo. Status: 404" ]
}

@test "add_branch fails to fetch SHA with HTTP 404" {
  echo '{"default_branch": "main"}' > mock_default_branch.json
  echo '{"message": "Branch not found"}' > mock_sha.json

  curl() {
    if echo "${*}" | grep -q -- '-o[[:space:]]\+default_branch.json'; then
      mock_curl "200" mock_default_branch.json "${*}"
    elif echo "${*}" | grep -q -- '-o[[:space:]]\+sha.json'; then
      mock_curl "404" mock_sha.json "${*}"
    fi
  }
  export -f curl

  jq() { 
    local flag="$1"
    local field="$2"
    local file="$3"
    
    if [ "$flag" = "-r" ]; then
      mock_jq "$field" "$file"
    else
      mock_jq "$flag" "$field"
    fi
  }
  export -f jq
  
  run add_branch "test-repo" "test-owner" "fake-token" "new-branch"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" == "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" == "error-message=Failed to fetch SHA for branch main in test-repo. Status: 404" ]
}

@test "add_branch fails to create branch with HTTP 422" {
  echo '{"default_branch": "main"}' > mock_default_branch.json
  echo '{"commit": {"sha": "abc123"}}' > mock_sha.json
  echo '{"message": "Reference already exists"}' > mock_create_response.json

  curl() {
    if echo "${*}" | grep -q -- '-o[[:space:]]\+default_branch.json'; then
      mock_curl "200" mock_default_branch.json "${*}"
    elif echo "${*}" | grep -q -- '-o[[:space:]]\+sha.json'; then
      mock_curl "200" mock_sha.json "${*}"
    elif echo "${*}" | grep -q -- '-o[[:space:]]\+create_response.json'; then
      mock_curl "422" mock_create_response.json "${*}"
    fi
  }
  export -f curl

  jq() { 
    local flag="$1"
    local field="$2"
    local file="$3"
    
    if [ "$flag" = "-r" ]; then
      mock_jq "$field" "$file"
    else
      mock_jq "$flag" "$field"
    fi
  }
  export -f jq

  run add_branch "test-repo" "test-owner" "fake-token" "new-branch"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" == "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" == "error-message=Failed to create branch new-branch: Reference already exists" ]
}

@test "add_branch fails with empty repo_name" {
  run add_branch "" "test-owner" "fake-token" "new-branch"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" == "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" == "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided." ]
}

@test "add_branch fails with empty owner" {
  run add_branch "test-repo" "" "fake-token" "new-branch"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" == "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" == "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided." ]
}

@test "add_branch fails with empty token" {
  run add_branch "test-repo" "test-owner" "" "new-branch"

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" == "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" == "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided." ]
}

@test "add_branch fails with empty branch_name" {
  run add_branch "test-repo" "test-owner" "fake-token" ""

  [ "$status" -eq 0 ]
  [ "$(grep 'result' "$GITHUB_OUTPUT")" == "result=failure" ]
  [ "$(grep 'error-message' "$GITHUB_OUTPUT")" == "error-message=Missing required parameters: repo_name, branch_name, owner, and token must be provided." ]
}
