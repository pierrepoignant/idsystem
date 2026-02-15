@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: Order Import with SQLite Tracking
:: ============================================================================
::
:: Prerequisites:
::   - sqlite3.exe must be in PATH or next to this script
::     Download from https://www.sqlite.org/download.html
::     ("Precompiled Binaries for Windows" > sqlite-tools-win-x64-*.zip)
::   - The database file (idsystem.db) is auto-created on first run
::
:: ============================================================================

:: --- Configuration ---
set "FLOW_EXE=F:\LGI\Gestcom\Flow.exe"
set "DB_NAME=idsystem.db"
set "USR=LBCScript"
set "PWDC=hfnS02e2F6EvV/A"
set "DBN=ESSENCIAGUA"
set "FTP_PATH=/upload/ess_commandes_export"
set "IMPORT_PATH=F:\LBCScripts\imports2\shopify"
set "PROFIL=Shopify"
set "API_BASE=https://lesbonneschoses.app/oms2"

:: --- Channels (add new channels here) ---
set "CHANNELS=1 10"
set "CHANNEL_1_NAME=Shopify B2C"
set "CHANNEL_10_NAME=Prestashop ES"

:: --- Defaults ---
set "CHANNEL_ID=1"
set "CHANNEL_NAME=!CHANNEL_1_NAME!"
set "DATE_SINCE="

:: --- Check command-line argument for channel ---
if not "%~1"=="" (
    set "CHANNEL_ID=%~1"
    set "CHANNEL_NAME=!CHANNEL_%~1_NAME!"
    if "!CHANNEL_NAME!"=="" (
        echo ERROR: Unknown channel ID: %~1
        exit /b 1
    )
)

:: ============================================================================
:: MAIN MENU
:: ============================================================================
:MAIN_MENU
cls
echo ========================================================================
echo Order Import with SQLite Tracking
echo ========================================================================
echo.
if "%CHANNEL_ID%"=="" (
    echo Current Channel: Not selected
) else (
    echo Current Channel: %CHANNEL_NAME% [ID: %CHANNEL_ID%]
)
if "%DATE_SINCE%"=="" (
    echo Date Since:      Today
) else (
    echo Date Since:      %DATE_SINCE%
)
echo.
echo 0. Select Channel
echo 1. Set Date
echo.
echo 2. Run Import
echo.
echo Q. Quit
echo.
echo ========================================================================
set /p choice="Enter your choice: "

if /i "%choice%"=="0" goto SELECT_CHANNEL
if /i "%choice%"=="1" goto SET_DATE
if /i "%choice%"=="2" goto RUN_IMPORT
if /i "%choice%"=="Q" goto END

echo Invalid choice. Try again.
pause
goto MAIN_MENU


:: ============================================================================
:: CHANNEL SELECTION
:: ============================================================================
:SELECT_CHANNEL
cls
echo ========================================================================
echo Select Channel
echo ========================================================================
echo.
for %%c in (%CHANNELS%) do (
    echo %%c. !CHANNEL_%%c_NAME!
)
echo.
echo  0. Back to menu
echo.
echo ========================================================================
set /p channel="Enter channel ID: "

if "%channel%"=="0" goto MAIN_MENU
set "CHANNEL_NAME=!CHANNEL_%channel%_NAME!"
if "!CHANNEL_NAME!"=="" (
    echo Invalid channel ID.
    pause
    goto SELECT_CHANNEL
)
set "CHANNEL_ID=%channel%"
goto MAIN_MENU


:: ============================================================================
:: SET DATE
:: ============================================================================
:SET_DATE
cls
echo ========================================================================
echo Set Date Since (YYYY-MM-DD format, or leave blank for today)
echo ========================================================================
echo.
set "input_date="
set /p input_date="Date since: "
if "%input_date%"=="" (
    set "DATE_SINCE="
    echo Using today's date.
) else (
    set "DATE_SINCE=%input_date%"
    echo Date set to %input_date%.
)
pause
goto MAIN_MENU


:: ============================================================================
:: RUN IMPORT
:: ============================================================================
:RUN_IMPORT
if "%CHANNEL_ID%"=="" (
    echo ERROR: Select a channel first.
    pause
    goto MAIN_MENU
)

echo.
echo ========================================================================
echo Initializing database...
echo ========================================================================

:: Init DB - create table if not exists
sqlite3 "%DB_NAME%" "CREATE TABLE IF NOT EXISTS imported_orders (order_id INTEGER PRIMARY KEY, channel_id INTEGER NOT NULL, source_id TEXT, imported_at TEXT DEFAULT (datetime('now')));"
if errorlevel 1 (
    echo ERROR: Failed to initialize database. Is sqlite3.exe in PATH?
    pause
    goto MAIN_MENU
)
echo Database ready.

echo.
echo ========================================================================
echo Fetching and importing orders for %CHANNEL_NAME% [ID: %CHANNEL_ID%]...
echo ========================================================================
echo.

:: Compute today's date if DATE_SINCE is not set
if "%DATE_SINCE%"=="" (
    for /f %%d in ('powershell -Command "(Get-Date).ToString('yyyy-MM-dd')"') do set "DATE_SINCE_FINAL=%%d"
) else (
    set "DATE_SINCE_FINAL=%DATE_SINCE%"
)

:: Main import loop via PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 $ErrorActionPreference = 'Stop';^
 $apiBase = '%API_BASE%';^
 $channelId = '%CHANNEL_ID%';^
 $dateSince = '%DATE_SINCE_FINAL%';^
 $dbName = '%DB_NAME%';^
 $flowExe = '%FLOW_EXE%';^
 $dbn = '%DBN%';^
 $usr = '%USR%';^
 $pwdc = '%PWDC%';^
 $ftpPath = '%FTP_PATH%';^
 $importPath = '%IMPORT_PATH%';^
 $profil = '%PROFIL%';^
 $imported = 0;^
 $skipped = 0;^
 $failed = 0;^
 ^
 try {^
     Write-Host \"Fetching orders from API: $apiBase/get-new-orders/$channelId/$dateSince\";^
     $response = Invoke-RestMethod -Uri \"$apiBase/get-new-orders/$channelId/$dateSince\";^
 } catch {^
     Write-Host \"ERROR: Failed to fetch orders from API: $_\";^
     exit 1;^
 }^
 ^
 if (-not $response.orders -or $response.orders.Count -eq 0) {^
     Write-Host 'No new orders found.';^
     exit 0;^
 }^
 ^
 $orders = $response.orders;^
 Write-Host \"Found $($orders.Count) order(s) to process.\";^
 Write-Host '';^
 ^
 foreach ($order in $orders) {^
     $orderId = $order.order_id;^
     $sourceId = $order.source_id;^
     Write-Host \"------------------------------------------------------------------------\";^
     Write-Host \"Processing order #$orderId (source: $sourceId)\";^
     ^
     $existing = (sqlite3 $dbName \"SELECT order_id FROM imported_orders WHERE order_id=$orderId;\") 2^>$null;^
     if ($existing) {^
         Write-Host \"  SKIP - already imported.\";^
         $skipped++;^
         continue;^
     }^
     ^
     try {^
         Write-Host \"  Triggering export...\";^
         Invoke-RestMethod -Uri \"$apiBase/export-to-idsystem/$channelId/order/$orderId\" ^| Out-Null;^
     } catch {^
         Write-Host \"  FAILED - export error: $_\";^
         $failed++;^
         continue;^
     }^
     ^
     Write-Host \"  Running FloW import...\";^
     ^& $flowExe -DBN $dbn -USR $usr -PWDC $pwdc -SKLOG -FCTN IMPORTORDER -NOFTP 2 -FTPPATH $ftpPath -PROFIL $profil -PATH $importPath;^
     if ($LASTEXITCODE -ne 0) {^
         Write-Host \"  FAILED - FloW import error (exit code: $LASTEXITCODE)\";^
         $failed++;^
         continue;^
     }^
     ^
     $safeSourceId = if ($sourceId) { $sourceId -replace \"'\", \"''\" } else { '' };^
     sqlite3 $dbName \"INSERT INTO imported_orders (order_id, channel_id, source_id) VALUES ($orderId, $channelId, '$safeSourceId');\";^
     if ($LASTEXITCODE -ne 0) {^
         Write-Host \"  WARNING - imported but failed to record in DB\";^
         $imported++;^
         continue;^
     }^
     ^
     Write-Host \"  OK - imported and recorded.\";^
     $imported++;^
 }^
 ^
 Write-Host '';^
 Write-Host '========================================================================';^
 Write-Host \"Summary: $imported imported, $skipped skipped, $failed failed\";^
 Write-Host '========================================================================';^
 ^
 if ($failed -gt 0) { exit 1 } else { exit 0 }

if errorlevel 1 (
    echo.
    echo Import completed with errors.
) else (
    echo.
    echo Import completed successfully.
)

pause
goto MAIN_MENU


:: ============================================================================
:: END
:: ============================================================================
:END
echo.
echo Exiting...
endlocal
exit /b 0
