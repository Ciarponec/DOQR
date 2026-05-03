param(
  [Parameter(Mandatory=$true)] [string]$SupabaseUrl,
  [Parameter(Mandatory=$true)] [string]$QrToken
)

$ring = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/functions/v1/qr-ring-create" -ContentType "application/json" -Body (@{ qr_token = $QrToken; visitor_alias = "smoke" } | ConvertTo-Json)
if (-not $ring.ring_id) { throw "ring_id missing" }
Write-Output "Ring OK: $($ring.ring_id)"

$msg = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/functions/v1/visitor-chat-send" -ContentType "application/json" -Body (@{ ring_id = $ring.ring_id; visitor_session_token = $ring.visitor_session_token; message_text = "smoke test" } | ConvertTo-Json)
if (-not $msg.message_id) { throw "message_id missing" }
Write-Output "Visitor chat OK: $($msg.message_id)"
