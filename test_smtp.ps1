# Load .env file
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        $line = $line.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line -match "^([^=]+)=(.*)$") {
            Set-Variable -Name $matches[1].Trim() -Value $matches[2].Trim()
        }
    }
} else {
    Write-Host "ERROR: .env file not found at $envFile"
    Write-Host 'Create a .env file with: SENDGRID_API_KEY=SG.your_key_here'
    exit 1
}

# SMTP Configuration
$Server   = "smtp.sendgrid.net"
$Port     = 587
$Login    = "apikey"
$Password = $SENDGRID_API_KEY
$From     = "pierre@essenciagua.com"
$FromName = "Pierre Equipe Essenciagua"
$To       = "pierre@essenciagua.com"

$ErrorActionPreference = "Stop"

# Force TLS 1.2 (required by SendGrid)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Write-Host "Connecting to ${Server}:${Port} (TLS 1.2)..."
    $smtp = New-Object System.Net.Mail.SmtpClient($Server, $Port)
    $smtp.EnableSsl = $true
    $smtp.Credentials = New-Object System.Net.NetworkCredential($Login, $Password)
    $smtp.Timeout = 10000

    Write-Host "Connected. Sending test email..."
    $msg = New-Object System.Net.Mail.MailMessage
    $msg.From = New-Object System.Net.Mail.MailAddress($From, $FromName)
    $msg.To.Add($To)
    $msg.Subject = "SMTP Test"
    $msg.Body = "This is a test email to verify SMTP connectivity."

    $smtp.Send($msg)
    Write-Host "Email sent successfully!"
} catch {
    Write-Host "FAILED: $_"
} finally {
    if ($smtp) { $smtp.Dispose() }
    if ($msg)  { $msg.Dispose() }
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
