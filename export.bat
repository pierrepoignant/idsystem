@echo off
setlocal ENABLEDELAYEDEXPANSION

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
echo   Q ^) Quit
echo.
set "CHOICE="
set /p CHOICE=Choice (1-4, Q to quit) : 

if /I "%CHOICE%"=="1" goto push_stock
if /I "%CHOICE%"=="2" goto push_articles
if /I "%CHOICE%"=="3" goto push_commandes
if /I "%CHOICE%"=="4" goto push_clients
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
 -NOFTP 3 ^
 -FTPPATH "/upload/ess_stocks"

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
 -NOFTP 3 ^
 -FTPPATH "/upload/ess_articles" ^
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
F:\Lgi\GestCom\FloW.exe ^
 -DBN "ESSENCIAGUA" ^
 -USR "LBCScript" ^
 -PWDC "hfnS02e2F6EvV/A" ^
 -SKLOG ^
 -FCTN FTPDIRUPLOAD ^
 -LOCALDIR "F:\LBCScripts\exports2\commandes\*.csv" ^
 -NOFTP 3 ^
 -FTPPATH "/upload/ess_commandes" ^
 -ARCHIVEDIR

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
 -NOFTP 3 ^
 -FTPPATH "/upload/ess_clients" ^
 -FILTRE "CUSDATEL>='%DATE_SINCE%'"

echo.
pause
goto menu

:end
echo Done.
endlocal
