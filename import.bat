@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: Order Import with SQLite Tracking
:: ============================================================================
::
:: Prerequisites:
::   - sqlite3.exe must be in PATH or next to this script
::   - curl.exe must be in PATH or next to this script
::   - The database file (idsystem.db) is auto-created on first run
::
:: ============================================================================

:: --- Configuration ---
set "FLOW_EXE=F:\LGI\Gestcom\Flow.exe"
set "DB_NAME=idsystem.db"
set "USR=LBCScript"
set "PWDC=hfnS02e2F6EvV/A"
set "DBN=ESSENCIAGUA"
set "IMPORT_PATH=F:\LBCScripts\imports2\commandes"
set "PROFIL=Prestashop"
set "API_BASE=https://lesbonneschoses.app/oms2"
set "PS_SCRIPT=%~dp0import_orders.ps1"

:: --- FTP Configuration ---
set "FTP_SERVER=91.134.130.254"
set "FTP_USER=lbcapp"
set "FTP_PASS=123LesBonnesChoses$"
set "FTP_DIR_ORDERS=/ess_commandes_export"
set "FTP_DIR_CUSTOMERS=/ess_clients_export"
set "IMPORT_PATH_CUSTOMERS=F:\LBCScripts\imports2\clients"

:: --- Channels (add new channels here) ---
set "CHANNELS=1 10"
set "CHANNEL_1_NAME=Shopify B2C"
set "CHANNEL_10_NAME=Prestashop ES"

:: --- Defaults ---
set "CHANNEL_ID=1"
set "CHANNEL_NAME=!CHANNEL_1_NAME!"
set "DATE_SINCE="

:: --- Compute default date from last imported order ---
sqlite3 "%DB_NAME%" "CREATE TABLE IF NOT EXISTS imported_orders (order_id INTEGER PRIMARY KEY, channel_id INTEGER NOT NULL, source_id TEXT, imported INTEGER DEFAULT 0, created_at TEXT DEFAULT (datetime('now')), imported_at TEXT);" 2>nul
for /f %%d in ('sqlite3 "%DB_NAME%" "SELECT date(MAX(imported_at)) FROM imported_orders WHERE imported=1;" 2^>nul') do (
    if not "%%d"=="" set "DATE_SINCE=%%d"
)

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
echo Current Channel: %CHANNEL_NAME% [ID: %CHANNEL_ID%]
if "%DATE_SINCE%"=="" (
    echo Date Since:      Today
) else (
    echo Date Since:      %DATE_SINCE%
)
echo Import Path:     %IMPORT_PATH%
echo.
echo 0. Select Channel
echo S. Set Date
echo.
echo 1. Prepare Import (export + FTP download + clean duplicates)
echo 2. Import Customers
echo 3. Import Orders
echo.
echo 4. Full Import (1+2+3)
echo.
echo Q. Quit
echo.
echo ========================================================================
set /p choice="Enter your choice: "

if /i "%choice%"=="0" goto SELECT_CHANNEL
if /i "%choice%"=="S" goto SET_DATE
if /i "%choice%"=="1" goto STEP_PREPARE
if /i "%choice%"=="2" goto STEP_IMPORT_CUSTOMERS
if /i "%choice%"=="3" goto STEP_IMPORT_ORDERS
if /i "%choice%"=="4" goto FULL_IMPORT
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
:: INIT DB (called before steps that need it)
:: ============================================================================
:INIT_DB
sqlite3 "%DB_NAME%" "CREATE TABLE IF NOT EXISTS imported_orders (order_id INTEGER PRIMARY KEY, channel_id INTEGER NOT NULL, source_id TEXT, imported INTEGER DEFAULT 0, created_at TEXT DEFAULT (datetime('now')), imported_at TEXT);"
if errorlevel 1 (
    echo ERROR: Failed to initialize database. Is sqlite3.exe in PATH?
    exit /b 1
)
:: Migrate old schema: add imported column if missing
sqlite3 "%DB_NAME%" "ALTER TABLE imported_orders ADD COLUMN imported INTEGER DEFAULT 0;" 2>nul
sqlite3 "%DB_NAME%" "ALTER TABLE imported_orders ADD COLUMN created_at TEXT;" 2>nul
exit /b 0


:: ============================================================================
:: STEP 1: Trigger CSV Export
:: ============================================================================
:STEP_TRIGGER
echo.
echo ========================================================================
echo Step 1: Trigger CSV Export for %CHANNEL_NAME%
echo ========================================================================
echo.

call :INIT_DB
if errorlevel 1 (
    pause
    goto MAIN_MENU
)

:: Compute today's date if DATE_SINCE is not set
if "%DATE_SINCE%"=="" (
    for /f %%d in ('powershell -Command "(Get-Date).ToString('yyyy-MM-dd')"') do set "DATE_SINCE_FINAL=%%d"
) else (
    set "DATE_SINCE_FINAL=%DATE_SINCE%"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step TriggerExport -ApiBase "%API_BASE%" -ChannelId "%CHANNEL_ID%" -DateSince "%DATE_SINCE_FINAL%" -DbName "%DB_NAME%"

if errorlevel 1 (
    echo.
    echo Step 1 FAILED.
) else (
    echo.
    echo Step 1 completed.
)
pause
goto MAIN_MENU


:: ============================================================================
:: STEP 2: Download from FTP
:: ============================================================================
:STEP_FTP
echo.
echo ========================================================================
echo Step 2: Download from FTP
echo ========================================================================

echo.
echo --- Orders: %FTP_DIR_ORDERS% to %IMPORT_PATH% ---
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step FtpDownload -FtpServer "%FTP_SERVER%" -FtpUser "%FTP_USER%" -FtpPass "%FTP_PASS%" -FtpDir "%FTP_DIR_ORDERS%" -ImportPath "%IMPORT_PATH%"

echo.
echo --- Customers: %FTP_DIR_CUSTOMERS% to %IMPORT_PATH_CUSTOMERS% ---
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step FtpDownload -FtpServer "%FTP_SERVER%" -FtpUser "%FTP_USER%" -FtpPass "%FTP_PASS%" -FtpDir "%FTP_DIR_CUSTOMERS%" -ImportPath "%IMPORT_PATH_CUSTOMERS%"

echo.
echo Step 2 completed.
pause
goto MAIN_MENU


:: ============================================================================
:: STEP 3: Clean duplicate files
:: ============================================================================
:STEP_CLEAN
echo.
echo ========================================================================
echo Step 3: Clean duplicate files in %IMPORT_PATH%
echo ========================================================================
echo.

call :INIT_DB
if errorlevel 1 (
    pause
    goto MAIN_MENU
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step CleanDuplicates -DbName "%DB_NAME%" -ImportPath "%IMPORT_PATH%"

echo.
echo Step 3 completed.
pause
goto MAIN_MENU


:: ============================================================================
:: MENU 1: Prepare Import (trigger export + FTP download + clean duplicates)
:: ============================================================================
:STEP_PREPARE
echo.
echo ========================================================================
echo Prepare Import for %CHANNEL_NAME% [ID: %CHANNEL_ID%]
echo ========================================================================

call :INIT_DB
if errorlevel 1 (
    pause
    goto MAIN_MENU
)

:: Compute today's date if DATE_SINCE is not set
if "%DATE_SINCE%"=="" (
    for /f %%d in ('powershell -Command "(Get-Date).ToString('yyyy-MM-dd')"') do set "DATE_SINCE_FINAL=%%d"
) else (
    set "DATE_SINCE_FINAL=%DATE_SINCE%"
)

echo.
echo --- Trigger CSV Export ---
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step TriggerExport -ApiBase "%API_BASE%" -ChannelId "%CHANNEL_ID%" -DateSince "%DATE_SINCE_FINAL%" -DbName "%DB_NAME%"
if errorlevel 1 (
    echo.
    echo ABORTED: CSV export failed.
    pause
    goto MAIN_MENU
)

echo.
echo --- Download from FTP (orders) ---
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step FtpDownload -FtpServer "%FTP_SERVER%" -FtpUser "%FTP_USER%" -FtpPass "%FTP_PASS%" -FtpDir "%FTP_DIR_ORDERS%" -ImportPath "%IMPORT_PATH%"

echo.
echo --- Download from FTP (customers) ---
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step FtpDownload -FtpServer "%FTP_SERVER%" -FtpUser "%FTP_USER%" -FtpPass "%FTP_PASS%" -FtpDir "%FTP_DIR_CUSTOMERS%" -ImportPath "%IMPORT_PATH_CUSTOMERS%"

echo.
echo --- Clean duplicate files ---
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step CleanDuplicates -DbName "%DB_NAME%" -ImportPath "%IMPORT_PATH%"

echo.
echo Prepare Import completed.
pause
goto MAIN_MENU


:: ============================================================================
:: MENU 2: Import Customers
:: ============================================================================
:STEP_IMPORT_CUSTOMERS
echo.
echo ========================================================================
echo Import Customers from %IMPORT_PATH_CUSTOMERS%
echo ========================================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step ImportCustomers -CustomerImportPath "%IMPORT_PATH_CUSTOMERS%" -FlowExe "%FLOW_EXE%" -Dbn "%DBN%" -Usr "%USR%" -Pwdc "%PWDC%" -Profil "%PROFIL%"

echo.
echo Import Customers completed.
pause
goto MAIN_MENU


:: ============================================================================
:: MENU 3: Import Orders
:: ============================================================================
:STEP_IMPORT_ORDERS
echo.
echo ========================================================================
echo Import Orders from %IMPORT_PATH%
echo ========================================================================
echo.

call :INIT_DB
if errorlevel 1 (
    pause
    goto MAIN_MENU
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step ImportOrders -DbName "%DB_NAME%" -ImportPath "%IMPORT_PATH%" -ChannelId "%CHANNEL_ID%" -FlowExe "%FLOW_EXE%" -Dbn "%DBN%" -Usr "%USR%" -Pwdc "%PWDC%" -Profil "%PROFIL%"

echo.
echo Import Orders completed.
pause
goto MAIN_MENU


:: ============================================================================
:: FULL IMPORT (Prepare + Customers + Orders)
:: ============================================================================
:FULL_IMPORT
echo.
echo ========================================================================
echo Full Import for %CHANNEL_NAME% [ID: %CHANNEL_ID%]
echo ========================================================================

call :INIT_DB
if errorlevel 1 (
    pause
    goto MAIN_MENU
)

:: Compute today's date if DATE_SINCE is not set
if "%DATE_SINCE%"=="" (
    for /f %%d in ('powershell -Command "(Get-Date).ToString('yyyy-MM-dd')"') do set "DATE_SINCE_FINAL=%%d"
) else (
    set "DATE_SINCE_FINAL=%DATE_SINCE%"
)

echo.
echo --- Trigger CSV Export ---
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step TriggerExport -ApiBase "%API_BASE%" -ChannelId "%CHANNEL_ID%" -DateSince "%DATE_SINCE_FINAL%" -DbName "%DB_NAME%"
if errorlevel 1 (
    echo.
    echo ABORTED: CSV export failed.
    pause
    goto MAIN_MENU
)

echo.
echo --- Download from FTP (orders) ---
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step FtpDownload -FtpServer "%FTP_SERVER%" -FtpUser "%FTP_USER%" -FtpPass "%FTP_PASS%" -FtpDir "%FTP_DIR_ORDERS%" -ImportPath "%IMPORT_PATH%"

echo.
echo --- Download from FTP (customers) ---
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step FtpDownload -FtpServer "%FTP_SERVER%" -FtpUser "%FTP_USER%" -FtpPass "%FTP_PASS%" -FtpDir "%FTP_DIR_CUSTOMERS%" -ImportPath "%IMPORT_PATH_CUSTOMERS%"

echo.
echo --- Clean duplicate files ---
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step CleanDuplicates -DbName "%DB_NAME%" -ImportPath "%IMPORT_PATH%"

echo.
echo --- Import Customers ---
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step ImportCustomers -CustomerImportPath "%IMPORT_PATH_CUSTOMERS%" -FlowExe "%FLOW_EXE%" -Dbn "%DBN%" -Usr "%USR%" -Pwdc "%PWDC%" -Profil "%PROFIL%"

echo.
echo --- Import Orders ---
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Step ImportOrders -DbName "%DB_NAME%" -ImportPath "%IMPORT_PATH%" -ChannelId "%CHANNEL_ID%" -FlowExe "%FLOW_EXE%" -Dbn "%DBN%" -Usr "%USR%" -Pwdc "%PWDC%" -Profil "%PROFIL%"

echo.
echo ========================================================================
echo Full import completed.
echo ========================================================================

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
