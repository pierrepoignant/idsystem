param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('TriggerExport','FtpDownload','CleanDuplicates','ImportAndRecord')]
    [string]$Step,

    [string]$ApiBase,
    [string]$ChannelId,
    [string]$DateSince,
    [string]$DbName,
    [string]$ImportPath,
    [string]$FtpServer,
    [string]$FtpUser,
    [string]$FtpPass,
    [string]$FtpDir,
    [string]$FlowExe,
    [string]$Dbn,
    [string]$Usr,
    [string]$Pwdc,
    [string]$Profil
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Step 1: Fetch new orders from API, check DB, trigger CSV export for new ones
# ---------------------------------------------------------------------------
if ($Step -eq 'TriggerExport') {
    # 1.1 Fetch order list from API
    $url = "$ApiBase/get-new-orders/$ChannelId/$DateSince"
    Write-Host "Fetching orders from API: $url"
    try {
        $json = (curl.exe -s -f $url) -join ''
        if ($LASTEXITCODE -ne 0) { throw "curl failed (exit code: $LASTEXITCODE)" }
        $response = $json | ConvertFrom-Json
    } catch {
        Write-Host "ERROR: Failed to fetch orders from API: $_"
        exit 1
    }

    if (-not $response.orders -or $response.orders.Count -eq 0) {
        Write-Host "No new orders found."
        exit 0
    }

    $orders = $response.orders
    Write-Host "Found $($orders.Count) order(s) from API."
    Write-Host ''

    # 1.2 For each order, check DB and trigger export if new
    $exported = 0
    $skipped = 0
    $failed = 0

    foreach ($order in $orders) {
        $orderId = $order.order_id
        $sourceId = $order.source_id
        Write-Host "------------------------------------------------------------------------"
        Write-Host "Order #$orderId (source: $sourceId)"

        # Check if already imported
        $existing = (sqlite3 $DbName "SELECT order_id FROM imported_orders WHERE order_id=$orderId;") 2>$null
        if ($existing) {
            Write-Host "  SKIP - already imported."
            $skipped++
            continue
        }

        # Trigger CSV export for this order
        try {
            Write-Host "  Triggering CSV export..."
            $exportUrl = "$ApiBase/export-to-idsystem/$ChannelId/order/$orderId"
            curl.exe -s -f $exportUrl | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "curl failed (exit code: $LASTEXITCODE)" }
            Write-Host "  OK - export triggered."
            $exported++
        } catch {
            Write-Host "  FAILED - export error: $_"
            $failed++
        }
    }

    Write-Host ''
    Write-Host '========================================================================'
    Write-Host "Summary: $exported exported, $skipped skipped, $failed failed"
    Write-Host '========================================================================'

    if ($failed -gt 0) { exit 1 } else { exit 0 }
}

# ---------------------------------------------------------------------------
# Step 1: Download CSV files from FTP, then delete remote copies
# ---------------------------------------------------------------------------
if ($Step -eq 'FtpDownload') {
    $ftpBase = "ftp://$FtpServer$FtpDir"
    Write-Host "Listing files on FTP: $ftpBase"

    $listing = (curl.exe -s -u "${FtpUser}:${FtpPass}" "$ftpBase/") -join "`n"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: FTP listing failed (exit code: $LASTEXITCODE)"
        exit 1
    }

    # Extract .csv filenames from directory listing
    $files = @()
    foreach ($line in ($listing -split "`n")) {
        $line = $line.Trim()
        if ($line -match '\.csv$') {
            # Handle both simple listing and full ls -l format
            $filename = ($line -split '\s+')[-1]
            $files += $filename
        }
    }

    if ($files.Count -eq 0) {
        Write-Host "No CSV files found on FTP."
        exit 0
    }

    Write-Host "Found $($files.Count) file(s) to download."
    $downloaded = 0
    $errors = 0

    foreach ($file in $files) {
        Write-Host "  Downloading $file..."
        # URL-encode special characters in filename (#, $, etc.)
        $encodedFile = [Uri]::EscapeDataString($file)
        curl.exe -sS -f -u "${FtpUser}:${FtpPass}" "$ftpBase/$encodedFile" -o "$ImportPath\$file" 2>&1 | ForEach-Object { "$_" }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    FAILED to download."
            $errors++
            continue
        }

        Write-Host "  Deleting remote $file..."
        curl.exe -s -u "${FtpUser}:${FtpPass}" "ftp://$FtpServer/" -Q "DELE $FtpDir/$file" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    WARNING: downloaded but failed to delete remote copy."
        }

        $downloaded++
    }

    Write-Host ""
    Write-Host "FTP download complete: $downloaded downloaded, $errors errors."
    if ($errors -gt 0) { exit 1 } else { exit 0 }
}

# ---------------------------------------------------------------------------
# Step 2: Clean duplicate CSV files (already imported orders)
# ---------------------------------------------------------------------------
if ($Step -eq 'CleanDuplicates') {
    $csvFiles = Get-ChildItem -Path $ImportPath -Filter '*.csv' -ErrorAction SilentlyContinue
    if (-not $csvFiles -or $csvFiles.Count -eq 0) {
        Write-Host "No CSV files in import folder."
        exit 0
    }

    Write-Host "Checking $($csvFiles.Count) CSV file(s) for duplicates and already imported..."
    $deleted = 0
    $kept = 0
    $seenOrders = @{}

    foreach ($csv in $csvFiles) {
        try {
            $lines = Get-Content $csv.FullName
            if ($lines.Count -lt 2) {
                Write-Host "  $($csv.Name) - skipping (not enough lines)"
                $kept++
                continue
            }
            $orderId = ($lines[1] -split ';')[0].Trim('"')

            # Check if already imported in DB
            $existing = (sqlite3 $DbName "SELECT order_id FROM imported_orders WHERE order_id=$orderId;") 2>$null
            if ($existing) {
                Write-Host "  $($csv.Name) - order #$orderId already imported, deleting."
                Remove-Item $csv.FullName -Force
                $deleted++
                continue
            }

            # Check if duplicate in folder (same order_id already seen)
            if ($seenOrders.ContainsKey($orderId)) {
                Write-Host "  $($csv.Name) - order #$orderId duplicate in folder (keeping $($seenOrders[$orderId])), deleting."
                Remove-Item $csv.FullName -Force
                $deleted++
                continue
            }

            $seenOrders[$orderId] = $csv.Name
            Write-Host "  $($csv.Name) - order #$orderId is new, keeping."
            $kept++
        } catch {
            Write-Host "  $($csv.Name) - error reading file: $_"
            $kept++
        }
    }

    Write-Host ""
    Write-Host "Clean complete: $deleted deleted, $kept kept."
    exit 0
}

# ---------------------------------------------------------------------------
# Step 3: Import via FloW + record imported orders in DB
# ---------------------------------------------------------------------------
if ($Step -eq 'ImportAndRecord') {
    # Collect order numbers from CSV files before running FloW
    $csvFiles = Get-ChildItem -Path $ImportPath -Filter '*.csv' -ErrorAction SilentlyContinue
    if (-not $csvFiles -or $csvFiles.Count -eq 0) {
        Write-Host "No CSV files to import."
        exit 0
    }

    $orderMap = @{}
    foreach ($csv in $csvFiles) {
        try {
            $lines = Get-Content $csv.FullName
            if ($lines.Count -ge 2) {
                $orderId = ($lines[1] -split ';')[0].Trim('"')
                $orderMap[$orderId] = $csv.Name
            }
        } catch {
            Write-Host "  WARNING: could not read $($csv.Name)"
        }
    }

    Write-Host "Found $($orderMap.Count) order(s) to import: $($orderMap.Keys -join ', ')"
    Write-Host ""

    # Run FloW (runs in background, does not return exit code)
    Write-Host "Launching FloW import..."
    & $FlowExe -DBN $Dbn -USR $Usr -PWDC $Pwdc -SKLOG -FCTN IMPORTORDER -PATH $ImportPath -PROFIL $Profil
    Write-Host "FloW launched."
    Write-Host ""

    # Record imported orders in database
    $recorded = 0
    foreach ($entry in $orderMap.GetEnumerator()) {
        $orderId = $entry.Key
        $sourceFile = $entry.Value -replace "'", "''"
        sqlite3 $DbName "INSERT OR IGNORE INTO imported_orders (order_id, channel_id, source_id) VALUES ($orderId, $ChannelId, '$sourceFile');"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Recorded order #$orderId"
            $recorded++
        } else {
            Write-Host "  WARNING: failed to record order #$orderId"
        }
    }

    Write-Host ""
    Write-Host "Import complete: $recorded order(s) recorded in database."
    exit 0
}
