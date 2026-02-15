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

:: Main import loop via PowerShell script
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0import_orders.ps1" -ApiBase "%API_BASE%" -ChannelId "%CHANNEL_ID%" -DateSince "%DATE_SINCE_FINAL%" -DbName "%DB_NAME%" -FlowExe "%FLOW_EXE%" -Dbn "%DBN%" -Usr "%USR%" -Pwdc "%PWDC%" -FtpPath "%FTP_PATH%" -ImportPath "%IMPORT_PATH%" -Profil "%PROFIL%"

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
