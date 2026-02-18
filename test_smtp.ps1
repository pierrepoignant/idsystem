# SMTP Configuration
$Server   = "smtp.sendgrid.net"
$Port     = 587
$Login    = "apikey"
$Password = "" # Set your SendGrid API key here before running
$From     = "pierre@essenciagua.com"
$FromName = "Pierre Equipe Essenciagua"
$To       = "pierre@essenciagua.com"

if (-not $Password) {
    $Password = Read-Host "Enter SendGrid API key"
}

$ErrorActionPreference = "Stop"

try {
    Write-Host "Connecting to ${Server}:${Port}..."
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
