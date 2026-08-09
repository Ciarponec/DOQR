param(
  [Parameter(Mandatory = $true)] [string]$SupabaseUrl,
  [Parameter(Mandatory = $true)] [string]$PublishableKey,
  [Parameter(Mandatory = $true)] [string]$QrToken,
  [string]$ConsentVersion = "2026-08-01"
)

$commonHeaders = @{
  apikey = $PublishableKey
  Authorization = "Bearer $PublishableKey"
}

$auth = Invoke-RestMethod `
  -Method Post `
  -Uri "$SupabaseUrl/auth/v1/signup" `
  -Headers $commonHeaders `
  -ContentType "application/json" `
  -Body "{}"

if (-not $auth.access_token) { throw "Anonymous Auth access_token missing" }
$visitorHeaders = @{
  apikey = $PublishableKey
  Authorization = "Bearer $($auth.access_token)"
}

$context = Invoke-RestMethod `
  -Method Post `
  -Uri "$SupabaseUrl/functions/v1/visitor-door-context" `
  -Headers $visitorHeaders `
  -ContentType "application/json" `
  -Body (@{ qr_token = $QrToken } | ConvertTo-Json)

if (-not $context.door.label) { throw "Door context missing" }
Write-Output "Context OK: $($context.door.label)"

$ringBody = @{
  qr_token = $QrToken
  visitor_alias = "smoke"
  visitor_kind = "guest"
  requested_mode = "text"
  consent_version = $ConsentVersion
  client = @{
    device_key = "smoke-$([guid]::NewGuid())"
    language = "tr-TR"
    timezone = "Europe/Istanbul"
    platform = "powershell"
    screen = "smoke"
  }
} | ConvertTo-Json -Depth 4

$ring = Invoke-RestMethod `
  -Method Post `
  -Uri "$SupabaseUrl/functions/v1/qr-ring-create" `
  -Headers $visitorHeaders `
  -ContentType "application/json" `
  -Body $ringBody

if (-not $ring.ring_id) { throw "ring_id missing" }
Write-Output "Ring OK: $($ring.ring_id)"

$message = Invoke-RestMethod `
  -Method Post `
  -Uri "$SupabaseUrl/functions/v1/visitor-chat-send" `
  -Headers $visitorHeaders `
  -ContentType "application/json" `
  -Body (@{
    ring_id = $ring.ring_id
    message_text = "smoke test"
    client_message_id = [guid]::NewGuid().ToString()
  } | ConvertTo-Json)

if (-not $message.id) { throw "message id missing" }
Write-Output "Visitor chat OK: $($message.id)"
