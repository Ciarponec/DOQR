param(
  [string]$KeystorePath = "C:\Users\Blasphemy\Documents\DOQR-keys\doqr-upload.jks"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$propertiesPath = Join-Path $repoRoot "flutter_app\android\key.properties"

if (-not (Test-Path -LiteralPath $KeystorePath)) {
  throw "Keystore bulunamadı: $KeystorePath"
}

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool) {
  $candidates = @(
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
    "C:\Program Files\Java\jdk-17\bin\keytool.exe"
  )
  $keytoolPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
} else {
  $keytoolPath = $keytool.Source
}
if (-not $keytoolPath) {
  throw "keytool bulunamadı. Android Studio JBR veya JDK 17 kurulu olmalı."
}

function ConvertFrom-SecureValue([Security.SecureString]$Value) {
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
  }
}

function ConvertTo-PropertiesValue([string]$Value) {
  return $Value.Replace("\", "\\").Replace(":", "\:").Replace("=", "\=")
}

Write-Host "DOQR Android imzalama yapılandırması" -ForegroundColor Cyan
$storeSecure = Read-Host "Keystore parolası" -AsSecureString
$keySecure = Read-Host "Alias parolası (aynıysa boş bırakın)" -AsSecureString
$storePassword = ConvertFrom-SecureValue $storeSecure
$keyPassword = ConvertFrom-SecureValue $keySecure
if ([string]::IsNullOrEmpty($keyPassword)) { $keyPassword = $storePassword }

& $keytoolPath -list -keystore $KeystorePath -alias "doqr-upload" -storepass $storePassword *> $null
if ($LASTEXITCODE -ne 0) {
  throw "Keystore parolası veya alias hatalı. Dosya oluşturulmadı."
}

$lines = @(
  "storePassword=$(ConvertTo-PropertiesValue $storePassword)",
  "keyPassword=$(ConvertTo-PropertiesValue $keyPassword)",
  "keyAlias=doqr-upload",
  "storeFile=$(ConvertTo-PropertiesValue $KeystorePath)"
)
[IO.File]::WriteAllLines($propertiesPath, $lines, [Text.UTF8Encoding]::new($false))

$storePassword = $null
$keyPassword = $null
Write-Host "`nBaşarılı: Android imzalama ayarı hazırlandı." -ForegroundColor Green
Write-Host "Bu pencereyi kapatıp Codex'e 'hazır' yazabilirsiniz."
Read-Host "Kapatmak için Enter"
