param(
  [string]$Url
)

$ErrorActionPreference = 'Stop'

if (-not $Url) {
  $Url = $env:WIN_CA_HOST
}
if (-not $Url) {
  $Url = 'https://127.0.0.1:4443/'
}

$expectSuccess = $false
if ($env:WIN_CA_EXPECT_SUCCESS) {
  $expectSuccess = ($env:WIN_CA_EXPECT_SUCCESS).ToLowerInvariant() -in @('1', 'true', 'yes')
}

$handler = [System.Net.Http.HttpClientHandler]::new()
$client = [System.Net.Http.HttpClient]::new($handler)

$succeeded = $false
try {
  $response = $client.GetAsync($Url).GetAwaiter().GetResult()
  try {
    $response.EnsureSuccessStatusCode() | Out-Null
  } finally {
    $response.Dispose()
  }
  $succeeded = $true
} catch {
  $err = $_
  Write-Host "Request to $Url failed: $($err.Exception.Message)"
} finally {
  $client.Dispose()
  $handler.Dispose()
}

if ($succeeded) {
  if (-not $expectSuccess) {
    Write-Error "Expected $Url to fail before trusting the test root"
    exit 1
  }
  Write-Host "win-ca smoke expectation met (expectSuccess=$expectSuccess, succeeded=$succeeded)"
  exit 0
} else {
  if ($expectSuccess) {
    Write-Error "Expected $Url to succeed after trusting the test root"
    exit 1
  }
  Write-Host "win-ca smoke expectation met (expectSuccess=$expectSuccess, succeeded=$succeeded)"
  exit 1
}
