param(
    [string]$ApiBase,
    [string]$ChannelId,
    [string]$DateSince,
    [string]$DbName,
    [string]$FlowExe,
    [string]$Dbn,
    [string]$Usr,
    [string]$Pwdc,
    [string]$FtpPath,
    [string]$ImportPath,
    [string]$Profil
)

$ErrorActionPreference = 'Stop'

$imported = 0
$skipped = 0
$failed = 0

try {
    Write-Host "Fetching orders from API: $ApiBase/get-new-orders/$ChannelId/$DateSince"
    $json = (curl.exe -s -f "$ApiBase/get-new-orders/$ChannelId/$DateSince") -join ''
    if ($LASTEXITCODE -ne 0) { throw "curl failed (exit code: $LASTEXITCODE)" }
    $response = $json | ConvertFrom-Json
} catch {
    Write-Host "ERROR: Failed to fetch orders from API: $_"
    exit 1
}

if (-not $response.orders -or $response.orders.Count -eq 0) {
    Write-Host 'No new orders found.'
    exit 0
}

$orders = $response.orders
Write-Host "Found $($orders.Count) order(s) to process."
Write-Host ''

foreach ($order in $orders) {
    $orderId = $order.order_id
    $sourceId = $order.source_id
    Write-Host "------------------------------------------------------------------------"
    Write-Host "Processing order #$orderId (source: $sourceId)"

    $existing = (sqlite3 $DbName "SELECT order_id FROM imported_orders WHERE order_id=$orderId;") 2>$null
    if ($existing) {
        Write-Host "  SKIP - already imported."
        $skipped++
        continue
    }

    try {
        Write-Host "  Triggering export..."
        curl.exe -s -f "$ApiBase/export-to-idsystem/$ChannelId/order/$orderId" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "curl failed (exit code: $LASTEXITCODE)" }
    } catch {
        Write-Host "  FAILED - export error: $_"
        $failed++
        continue
    }

    Write-Host "  Running FloW import..."
    & $FlowExe -DBN $Dbn -USR $Usr -PWDC $Pwdc -SKLOG -FCTN IMPORTORDER -NOFTP 3 -FTPPATH $FtpPath -PROFIL $Profil -PATH $ImportPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED - FloW import error (exit code: $LASTEXITCODE)"
        $failed++
        continue
    }

    $safeSourceId = if ($sourceId) { $sourceId -replace "'", "''" } else { '' }
    sqlite3 $DbName "INSERT INTO imported_orders (order_id, channel_id, source_id) VALUES ($orderId, $ChannelId, '$safeSourceId');"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  WARNING - imported but failed to record in DB"
        $imported++
        continue
    }

    Write-Host "  OK - imported and recorded."
    $imported++
}

Write-Host ''
Write-Host '========================================================================'
Write-Host "Summary: $imported imported, $skipped skipped, $failed failed"
Write-Host '========================================================================'

if ($failed -gt 0) { exit 1 } else { exit 0 }
