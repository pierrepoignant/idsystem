param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('SyncNewOrders','TriggerExport','FtpDownload','CleanDuplicates','ImportCustomers','ImportOrders')]
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
    [string]$Profil,
    [string]$CustomerImportPath
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Sync new orders: trigger import of new orders from the channel
# ---------------------------------------------------------------------------
if ($Step -eq 'SyncNewOrders') {
    $url = "$ApiBase/sync/new/$ChannelId"
    Write-Host "Syncing new orders from channel $ChannelId..."
    Write-Host "URL: $url"
    Write-Host ''
    try {
        $json = (curl.exe -s -f $url) -join ''
        if ($LASTEXITCODE -ne 0) { throw "curl failed (exit code: $LASTEXITCODE)" }
        $response = $json | ConvertFrom-Json
    } catch {
        Write-Host "ERROR: Failed to sync orders: $_"
        exit 1
    }

    if ($response.success) {
        Write-Host "Channel:  $($response.channel.name) ($($response.channel.type))"
        Write-Host "Imported: $($response.imported_count) order(s)"
        Write-Host "Skipped:  $($response.skipped_count) order(s)"
    } else {
        Write-Host "ERROR: Sync failed."
        Write-Host $json
        exit 1
    }

    exit 0
}

# ---------------------------------------------------------------------------
# Trigger CSV export: fetch orders from API, save to DB, trigger export
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

        # Check if already imported (imported=1)
        $rawResult = (sqlite3 $DbName "SELECT order_id FROM imported_orders WHERE order_id=$orderId AND imported=1;" 2>$null)
        $existing = ("$rawResult").Trim()
        if ($existing -ne '') {
            Write-Host "  SKIP - already imported."
            $skipped++
            continue
        }

        # Save order to DB (imported=0) if not already there
        $safeSourceId = if ($sourceId) { "$sourceId" -replace "'", "''" } else { '' }
        sqlite3 $DbName "INSERT OR IGNORE INTO imported_orders (order_id, channel_id, source_id) VALUES ($orderId, $ChannelId, '$safeSourceId');"

        # Trigger CSV export for this order
        try {
            Write-Host "  Triggering CSV export..."
            $exportUrl = "$ApiBase/export-to-idsystem/$ChannelId/order/$orderId"
            curl.exe -s -f $exportUrl | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "curl failed (exit code: $LASTEXITCODE)" }
            Write-Host "  OK - saved to DB + export triggered."
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
# FTP download: download CSV files, then delete remote copies
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
# Clean duplicate CSV files (already imported orders)
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
            $orderCode = [long](($lines[1] -split ';')[0].Trim('"'))
            $orderId = $orderCode - 90000000

            # Check if already imported in DB (imported=1)
            $rawResult = (sqlite3 $DbName "SELECT order_id FROM imported_orders WHERE order_id=$orderId AND imported=1;" 2>$null)
            $existing = ("$rawResult").Trim()
            if ($existing -ne '') {
                Write-Host "  $($csv.Name) - order #$orderId already imported (imported=1), deleting."
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
# Import customers via FloW
# ---------------------------------------------------------------------------
if ($Step -eq 'ImportCustomers') {
    $customerCsvFiles = Get-ChildItem -Path $CustomerImportPath -Filter '*.csv' -ErrorAction SilentlyContinue
    if (-not $customerCsvFiles -or $customerCsvFiles.Count -eq 0) {
        Write-Host "No customer CSV files to import."
        exit 0
    }

    Write-Host "Launching FloW customer import ($($customerCsvFiles.Count) file(s))..."
    & $FlowExe -DBN $Dbn -USR $Usr -PWDC $Pwdc -SKLOG -FCTN IMPORTCUSTOMER -PATH $CustomerImportPath -PROFIL $Profil
    Write-Host "FloW customer import launched."
    exit 0
}

# ---------------------------------------------------------------------------
# Import orders via FloW + record in DB
# ---------------------------------------------------------------------------
if ($Step -eq 'ImportOrders') {
    # Collect order numbers from CSV files before running FloW
    $csvFiles = Get-ChildItem -Path $ImportPath -Filter '*.csv' -ErrorAction SilentlyContinue
    if (-not $csvFiles -or $csvFiles.Count -eq 0) {
        Write-Host "No order CSV files to import."
        exit 0
    }

    $orderMap = @{}
    foreach ($csv in $csvFiles) {
        try {
            $lines = Get-Content $csv.FullName
            if ($lines.Count -ge 2) {
                $orderCode = [long](($lines[1] -split ';')[0].Trim('"'))
                $orderId = $orderCode - 90000000
                $orderMap["$orderId"] = $csv.Name
            }
        } catch {
            Write-Host "  WARNING: could not read $($csv.Name)"
        }
    }

    Write-Host "Found $($orderMap.Count) order(s) to import: $($orderMap.Keys -join ', ')"
    Write-Host ""

    Write-Host "Launching FloW order import..."
    & $FlowExe -DBN $Dbn -USR $Usr -PWDC $Pwdc -SKLOG -FCTN IMPORTORDER -PATH $ImportPath -PROFIL $Profil
    Write-Host "FloW order import launched."
    Write-Host ""

    # Mark orders as imported in database (single transaction)
    $sqlStatements = "BEGIN TRANSACTION;`n"
    foreach ($entry in $orderMap.GetEnumerator()) {
        $orderId = $entry.Key
        $sqlStatements += "UPDATE imported_orders SET imported=1, imported_at=datetime('now') WHERE order_id=$orderId;`n"
    }
    $sqlStatements += "COMMIT;"

    Write-Host "Marking $($orderMap.Count) order(s) as imported..."
    $sqlStatements | sqlite3 $DbName
    if ($LASTEXITCODE -eq 0) {
        foreach ($entry in $orderMap.GetEnumerator()) {
            Write-Host "  Marked order #$($entry.Key) as imported"
        }
        Write-Host ""
        Write-Host "Import complete: $($orderMap.Count) order(s) marked as imported."
    } else {
        Write-Host "ERROR: Failed to mark orders as imported."
        exit 1
    }
    exit 0
}
