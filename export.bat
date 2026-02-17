@echo off
setlocal ENABLEDELAYEDEXPANSION

rem ============================
rem  FTP Configuration
rem ============================
set "FTP_SERVER=91.134.130.254"
set "FTP_USER=lbcapp"
set "FTP_PASS=123LesBonnesChoses$"

rem ============================
rem  Compute default date = today - 7 days in MM/DD/YYYY
rem ============================
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "(Get-Date).AddDays(-7).ToString('MM/dd/yyyy')"`) do set "DEFAULT_DATE=%%I"

:menu
cls
echo ==========================================
echo   ESSENCIAGUA - Exports FloW
echo   Default date: %DEFAULT_DATE%
echo ==========================================
echo.
echo   1 ^) Push stock
echo   2 ^) Push articles
echo   3 ^) Push commandes
echo   4 ^) Push clients
echo   5 ^) Push 1 order
echo   6 ^) Push orders by date
echo   Q ^) Quit
echo.
set "CHOICE="
set /p CHOICE=Choice (1-6, Q to quit) :

if /I "%CHOICE%"=="1" goto push_stock
if /I "%CHOICE%"=="2" goto push_articles
if /I "%CHOICE%"=="3" goto push_commandes
if /I "%CHOICE%"=="4" goto push_clients
if /I "%CHOICE%"=="5" goto push_one_order
if /I "%CHOICE%"=="6" goto push_orders_by_date
if /I "%CHOICE%"=="Q" goto end

echo.
echo Invalid choice.
pause
goto menu

rem ============================
rem  Ask for date (shared function)
rem ============================
:ask_date
echo.
set "DATE_SINCE=%DEFAULT_DATE%"
set "INPUT_DATE="
set /p INPUT_DATE=Start date (mm/dd/yyyy) [default: %DEFAULT_DATE%] : 

if not "%INPUT_DATE%"=="" set "DATE_SINCE=%INPUT_DATE%"

echo Using date : %DATE_SINCE%
echo.
goto :eof

rem ============================
rem  PUSH STOCK (no date)
rem ============================
:push_stock
echo.
echo Running STOCK export (no date filter)...

F:\Lgi\GestCom\FloW.exe ^
 -DBN "ESSENCIAGUA" ^
 -USR "LBCScript" ^
 -PWDC "hfnS02e2F6EvV/A" ^
 -SKLOG ^
 -FCTN EXPORTARTICLE ^
 -PATH "F:\LBCScripts\exports2\stocks" ^
 -XMLFILE "Stock" ^
 -NOFTP 5 ^
 -FTPPATH "/ess_stocks"

echo.
pause
goto menu

rem ============================
rem  PUSH ARTICLES
rem ============================
:push_articles
call :ask_date

echo Running ARTICLES export since %DATE_SINCE% ...

F:\Lgi\GestCom\FloW.exe ^
 -DBN "ESSENCIAGUA" ^
 -USR "LBCScript" ^
 -PWDC "hfnS02e2F6EvV/A" ^
 -SKLOG ^
 -FCTN EXPORTARTICLE ^
 -PATH "F:\LBCScripts\exports2\articles" ^
 -NOFTP 5 ^
 -FTPPATH "/ess_articles" ^
 -FILTRE "ARTDATEL>='%DATE_SINCE%'"

echo.
pause
goto menu

rem ============================
rem  PUSH COMMANDES
rem ============================
:push_commandes
call :ask_date

echo Running COMMANDES export since %DATE_SINCE% ...

rem 1/ Export orders
F:\Lgi\GestCom\FloW.exe ^
 -DBN "ESSENCIAGUA" ^
 -USR "LBCScript" ^
 -PWDC "hfnS02e2F6EvV/A" ^
 -SKLOG ^
 -FCTN FREEEXPORTORDER ^
 -FILTRE "ORDENTRYDATE>='%DATE_SINCE%'" ^
 -PATH "F:\LBCScripts\exports2\commandes"

rem 2/ FTP upload
call :ftp_upload "F:\LBCScripts\exports2\commandes" "/ess_commandes"

rem 3/ Delete local CSV files
echo Deleting local CSV files in commandes directory...
del /Q "F:\LBCScripts\exports2\commandes\*.csv"

echo.
pause
goto menu

rem ============================
rem  PUSH 1 ORDER (by order number)
rem ============================
:push_one_order
echo.
set "ORDER_NUM="
set /p ORDER_NUM=Order number to export : 

if "!ORDER_NUM!"=="" (
  echo No order number entered.
  pause
  goto menu
)

echo Running COMMANDES export for order !ORDER_NUM! ...

rem 1/ Export single order
F:\Lgi\GestCom\FloW.exe ^
 -DBN "ESSENCIAGUA" ^
 -USR "LBCScript" ^
 -PWDC "hfnS02e2F6EvV/A" ^
 -SKLOG ^
 -FCTN FREEEXPORTORDER ^
 -FILTRE "ORDNOORDER=!ORDER_NUM!" ^
 -PATH "F:\LBCScripts\exports2\commandes"

rem 2/ FTP upload
call :ftp_upload "F:\LBCScripts\exports2\commandes" "/ess_commandes"

rem 3/ Delete local CSV files
echo Deleting local CSV files in commandes directory...
del /Q "F:\LBCScripts\exports2\commandes\*.csv"

echo.
pause
goto menu

rem ============================
rem  PUSH ORDERS BY DATE
rem ============================
:push_orders_by_date
echo.
set "EXACT_DATE="
set /p EXACT_DATE=Date to export (mm/dd/yyyy, e.g. 02/17/2026) :

if "!EXACT_DATE!"=="" (
  echo No date entered.
  pause
  goto menu
)

echo Running COMMANDES export for date !EXACT_DATE! ...

rem 1/ Export orders for that date
F:\Lgi\GestCom\FloW.exe ^
 -DBN "ESSENCIAGUA" ^
 -USR "LBCScript" ^
 -PWDC "hfnS02e2F6EvV/A" ^
 -SKLOG ^
 -FCTN FREEEXPORTORDER ^
 -FILTRE "ORDENTRYDATE='!EXACT_DATE!'" ^
 -PATH "F:\LBCScripts\exports2\commandes"

rem 2/ FTP upload
call :ftp_upload "F:\LBCScripts\exports2\commandes" "/ess_commandes"

rem 3/ Delete local CSV files
echo Deleting local CSV files in commandes directory...
del /Q "F:\LBCScripts\exports2\commandes\*.csv"

echo.
pause
goto menu

rem ============================
rem  PUSH CLIENTS
rem ============================
:push_clients
call :ask_date

echo Running CLIENTS export since %DATE_SINCE% ...

F:\Lgi\GestCom\FloW.exe ^
 -DBN "ESSENCIAGUA" ^
 -USR "LBCScript" ^
 -PWDC "hfnS02e2F6EvV/A" ^
 -SKLOG ^
 -FCTN EXPORTCUSTOMER ^
 -PATH "F:\LBCScripts\exports\clients" ^
 -NOFTP 5 ^
 -FTPPATH "/ess_clients" ^
 -FILTRE "CUSDATEL>='%DATE_SINCE%'"

echo.
pause
goto menu

rem ============================
rem  FTP upload subroutine
rem  Usage: call :ftp_upload "local_dir" "/remote_path"
rem ============================
:ftp_upload
set "FTP_LOCAL=%~1"
set "FTP_REMOTE=%~2"
echo.
echo Uploading CSV files from %FTP_LOCAL% to ftp://%FTP_SERVER%%FTP_REMOTE%/ ...
set "FTP_UPLOADED=0"
set "FTP_ERRORS=0"
for %%f in ("%FTP_LOCAL%\*.csv") do (
    echo   Uploading %%~nxf...
    curl -s -T "%%f" "ftp://%FTP_SERVER%%FTP_REMOTE%/" -u "%FTP_USER%:%FTP_PASS%"
    if errorlevel 1 (
        echo     FAILED
        set /a FTP_ERRORS+=1
    ) else (
        echo     OK
        set /a FTP_UPLOADED+=1
    )
)
echo FTP upload complete: !FTP_UPLOADED! uploaded, !FTP_ERRORS! errors.
goto :eof

:end
echo Done.
endlocal
