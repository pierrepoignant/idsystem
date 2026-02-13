@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: Customer and Order Synchronization Script (Windows compatible - no curl)
:: ============================================================================

:MAIN_MENU
cls
echo ========================================================================
echo Customer and Order Synchronization
echo ========================================================================
echo.
if "%SELECTED_CHANNEL%"=="" (
    echo Current Channel: Not selected
) else (
    echo Current Channel: %SELECTED_CHANNEL_NAME% (ID: %SELECTED_CHANNEL%)
)
echo.
echo 0. Select Channel
echo.
echo 1. Run All Steps
echo.
echo 2. Step 1: Import New Customers
echo 3. Step 2: Export New Customer IDs
echo 4. Step 3: Import New Orders
echo.
echo Q. Quit
echo.
echo ========================================================================
set /p choice="Enter your choice: "

if /i "%choice%"=="0" goto SELECT_CHANNEL
if /i "%choice%"=="1" goto RUN_ALL
if /i "%choice%"=="2" goto STEP1
if /i "%choice%"=="3" goto STEP2
if /i "%choice%"=="4" goto STEP3
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
echo 1. Prestashop ES
echo 10. Shopify B2B
echo 11. Shopify B2C
echo.
echo 0. Back to menu
echo.
echo ========================================================================
set /p channel="Enter channel ID: "

if "%channel%"=="1" (
    set SELECTED_CHANNEL=1
    set SELECTED_CHANNEL_NAME=Prestashop ES
    pause
    goto MAIN_MENU
)
if "%channel%"=="10" (
    set SELECTED_CHANNEL=10
    set SELECTED_CHANNEL_NAME=Shopify B2B
    pause
    goto MAIN_MENU
)
if "%channel%"=="11" (
    set SELECTED_CHANNEL=11
    set SELECTED_CHANNEL_NAME=Shopify B2C
    pause
    goto MAIN_MENU
)
if "%channel%"=="0" goto MAIN_MENU

echo Invalid channel ID.
pause
goto SELECT_CHANNEL


:: ============================================================================
:: RUN ALL
:: ============================================================================
:RUN_ALL
echo Running all steps...
echo.

if "%SELECTED_CHANNEL%"=="" (
    echo ERROR: Select a channel first.
    pause
    goto MAIN_MENU
)

call :EXECUTE_STEP1 || goto MAIN_MENU
call :EXECUTE_STEP2 || goto MAIN_MENU
call :EXECUTE_STEP3 || goto MAIN_MENU

echo.
echo All steps completed successfully.
pause
goto MAIN_MENU


:: ============================================================================
:: STEP 1 – Import New Customers
:: ============================================================================
:STEP1
if "%SELECTED_CHANNEL%"=="" (
    echo ERROR: Select a channel first.
    pause
    goto MAIN_MENU
)
call :EXECUTE_STEP1
pause
goto MAIN_MENU

:EXECUTE_STEP1
echo.
echo ------------------------------------------------------------------------
echo STEP 1: Import New Customers
echo ------------------------------------------------------------------------

echo Step 1.1: Export customers to IDSystem...
powershell -Command "Invoke-WebRequest -Uri 'https://lesbonneschoses.app/oms2/export-to-idsystem/customers/%SELECTED_CHANNEL%' -UseBasicParsing" >nul 2>&1
if errorlevel 1 (
    echo ERROR exporting customers.
    exit /b 1
)
echo Export OK.

echo.
echo Step 1.2: Import customers via FloW.exe...
"F:\LGI\Gestcom\Flow.exe" ^
 -DBN "ESSENCIAGUA" ^
 -USR "LBCScript" ^
 -PWDC "hfnS02e2F6EvV/A" ^
 -SKLOG ^
 -FCTN IMPORTCUSTOMER ^
 -NOFTP 3 ^
 -FTPPATH "/upload/ess_clients_export" ^
 -PATH "F:\LBCScripts\imports2\clients"

if errorlevel 1 (
    echo ERROR: FloW IMPORTCUSTOMER failed.
    exit /b 1
)

echo Step 1 completed.
exit /b 0


:: ============================================================================
:: STEP 2 – Export Customer IDs
:: ============================================================================
:STEP2
call :EXECUTE_STEP2
pause
goto MAIN_MENU

:EXECUTE_STEP2
echo.
echo ------------------------------------------------------------------------
echo STEP 2: Export New Customer IDs
echo ------------------------------------------------------------------------

:: Compute today's date in DD/MM/YYYY
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set dt=%%I
set DATE_SINCE=%dt:~6,2%/%dt:~4,2%/%dt:~0,4%

echo Step 2.1: Running FloW export since %DATE_SINCE%...

F:\Lgi\GestCom\FloW.exe ^
 -DBN "ESSENCIAGUA" ^
 -USR "LBCScript" ^
 -PWDC "hfnS02e2F6EvV/A" ^
 -SKLOG ^
 -FCTN EXPORTCUSTOMER ^
 -PATH "F:\LBCScripts\exports\clients" ^
 -NOFTP 3 ^
 -FTPPATH "/upload/ess_clients" ^
 -FILTRE "CUSDATEL>='%DATE_SINCE%'"

if errorlevel 1 (
    echo ERROR: FloW EXPORTCUSTOMER failed.
    exit /b 1
)

echo Export OK.

echo.
echo Step 2.2: Import into OMS2 via HTTP...
powershell -Command "Invoke-WebRequest -Method POST -Uri 'https://lesbonneschoses.app/oms2/ftp-import/cron/process-all/customers?location=local' -UseBasicParsing" >nul 2>&1

if errorlevel 1 (
    echo ERROR importing customers to OMS2.
    exit /b 1
)

echo Step 2 completed.
exit /b 0


:: ============================================================================
:: STEP 3 – Import New Orders
:: ============================================================================
:STEP3
if "%SELECTED_CHANNEL%"=="" (
    echo ERROR: Select a channel first.
    pause
    goto MAIN_MENU
)
call :EXECUTE_STEP3
pause
goto MAIN_MENU

:EXECUTE_STEP3
echo.
echo ------------------------------------------------------------------------
echo STEP 3: Import New Orders
echo ------------------------------------------------------------------------

echo Step 3.1: Export orders to IDSystem...

powershell -Command "Invoke-WebRequest -Uri 'https://lesbonneschoses.app/oms2/export-to-idsystem/orders/%SELECTED_CHANNEL%' -UseBasicParsing" >nul 2>&1
if errorlevel 1 (
    echo ERROR exporting orders.
    exit /b 1
)

echo Export OK.
echo.

echo Step 3.2: Import orders via FloW.exe...

"F:\LGI\Gestcom\Flow.exe" ^
 -DBN "ESSENCIAGUA" ^
 -USR "LBCScript" ^
 -PWDC "hfnS02e2F6EvV/A" ^
 -SKLOG ^
 -FCTN IMPORTORDER ^
 -NOFTP 2 ^
 -FTPPATH "/upload/ess_commandes_export" ^
 -PROFIL "Shopify" ^
 -PATH "F:\LBCScripts\imports2\shopify"

if errorlevel 1 (
    echo ERROR: FloW IMPORTORDER failed.
    exit /b 1
)

echo Step 3 completed.
exit /b 0


:: ============================================================================
:: END
:: ============================================================================
:END
echo.
echo Exiting...
endlocal
exit /b 0
