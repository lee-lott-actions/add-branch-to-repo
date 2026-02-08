param(
    [int]$Port = 3000
)

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()

Write-Host "Mock server listening on http://127.0.0.1:$Port..." -ForegroundColor Green

try {
    while ($listener.IsListening) {
        $context  = $listener.GetContext()
        $request  = $context.Request
        $response = $context.Response

        $path   = $request.Url.LocalPath
        $method = $request.HttpMethod

        Write-Host "Mock intercepted: $method $path" -ForegroundColor Cyan

        $statusCode   = 200
        $responseJson = $null

        # HealthCheck endpoint: GET /HealthCheck
        if ($method -eq "GET" -and $path -eq "/HealthCheck") {
            $statusCode = 200
            $responseJson = @{ status = "ok" } | ConvertTo-Json
        }
        # GET /repos/:owner/:repo
        elseif ($method -eq "GET" -and $path -match '^/repos/([^/]+)/([^/]+)$') {
            $owner = $Matches[1]
            $repo  = $Matches[2]

            Write-Host ("Mock intercepted: GET /repos/{0}/{1}" -f $owner, $repo) -ForegroundColor Cyan

            if (-not [string]::IsNullOrEmpty($owner) -and -not [string]::IsNullOrEmpty($repo)) {
                $statusCode = 200
                $responseJson = @{ default_branch = 'main' } | ConvertTo-Json -Compress
            }
            else {
                $statusCode = 404
                $responseJson = @{ message = 'Repository not found' } | ConvertTo-Json -Compress
            }
        }
        # GET /repos/:owner/:repo/branches/:branch
        elseif ($method -eq "GET" -and $path -match '^/repos/([^/]+)/([^/]+)/branches/([^/]+)$') {
            $owner  = $Matches[1]
            $repo   = $Matches[2]
            $branch = $Matches[3]

            Write-Host ("Mock intercepted: GET /repos/{0}/{1}/branches/{2}" -f $owner, $repo, $branch) -ForegroundColor Cyan

            if (-not [string]::IsNullOrEmpty($owner) -and
                -not [string]::IsNullOrEmpty($repo) -and
                $branch -eq 'main') {

                $statusCode = 200
                $responseJson = @{ commit = @{ sha = 'abc123' } } | ConvertTo-Json -Compress
            }
            else {
                $statusCode = 404
                $responseJson = @{ message = 'Branch not found' } | ConvertTo-Json -Compress
            }
        }
        # POST /repos/:owner/:repo/git/refs
        elseif ($method -eq "POST" -and $path -match '^/repos/([^/]+)/([^/]+)/git/refs$') {
            $owner = $Matches[1]
            $repo  = $Matches[2]

            Write-Host ("Mock intercepted: POST /repos/{0}/{1}/git/refs" -f $owner, $repo) -ForegroundColor Cyan

            $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
            $requestBody = $reader.ReadToEnd()
            $reader.Close()

            Write-Host "Request body: $requestBody"

            $bodyObj = $null
            try { $bodyObj = $requestBody | ConvertFrom-Json } catch { $bodyObj = $null }

            $ref = $null
            $sha = $null
            if ($null -ne $bodyObj) {
                $ref = $bodyObj.ref
                $sha = $bodyObj.sha
            }

            if (-not [string]::IsNullOrEmpty([string]$ref) -and
                -not [string]::IsNullOrEmpty([string]$sha) -and
                ($ref -like 'refs/heads/*')) {

                $statusCode = 201
                $responseJson = @{ ref = $ref } | ConvertTo-Json -Compress
            }
            else {
                $statusCode = 422
                $responseJson = @{ message = 'Reference already exists or invalid request' } | ConvertTo-Json -Compress
            }
        }
        else {
            $statusCode = 404
            $responseJson = @{ message = "Not Found" } | ConvertTo-Json -Compress
        }

        # Send response
        $response.StatusCode = $statusCode
        $response.ContentType = "application/json"

        $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseJson)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()
    }
}
finally {
    $listener.Stop()
    $listener.Close()
    Write-Host "Mock server stopped." -ForegroundColor Yellow
}