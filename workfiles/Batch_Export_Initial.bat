REM Export Commandes
"F:\LGI\Gestcom\Flow.exe" -DBN "ESSENCIAGUA" -USR "LBCScript"  -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN FREEEXPORTORDER -PATH "F:\LBCScripts\exports\commandes"

REM Export FTP Commandes
"F:\LGI\Gestcom\Flow.exe" -DBN "ESSENCIAGUA" -USR "LBCScript"  -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN  FTPDIRUPLOAD -LOCALDIR "F:\LBCScripts\exports\commandes\*.csv" -NOFTP 2 -FTPPATH "/var/www/essenciagua/idsystem/batch" -ARCHIVEDIR

