REM Export Articles
"F:\LGI\Gestcom\Flow.exe" -DBN "ESSENCIAGUA" -USR "LBCScript"  -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN EXPORTARTICLE -PATH "F:\LBCScripts\exports\articles" -NOFTP 2 -FTPPATH "/var/www/essenciagua/idsystem/articles" 

REM Export Stocks
"F:\LGI\Gestcom\Flow.exe" -DBN "ESSENCIAGUA" -USR "LBCScript"  -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN EXPORTARTICLE -PATH "F:\LBCScripts\exports\articles" -XMLFILE Stock -NOFTP 2 -FTPPATH "/var/www/essenciagua/idsystem/stocks" 

REM Export Clients
"F:\LGI\Gestcom\Flow.exe" -DBN "ESSENCIAGUA" -USR "LBCScript"  -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN EXPORTCUSTOMER -PATH "F:\LBCScripts\exports\clients" -NOFTP 2 -FTPPATH "/var/www/essenciagua/idsystem/clients" 

REM Export Commandes
"F:\LGI\Gestcom\Flow.exe" -DBN "ESSENCIAGUA" -USR "LBCScript"  -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN FREEEXPORTORDER -PATH "F:\LBCScripts\exports\commandes" -FILTRE "ORDENTRYDATE>='09/20/2025'" 

REM Export FTP Commandes
"F:\LGI\Gestcom\Flow.exe" -DBN "ESSENCIAGUA" -USR "LBCScript"  -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN  FTPDIRUPLOAD -LOCALDIR "F:\LBCScripts\exports\commandes\*.csv" -NOFTP 2 -FTPPATH "/var/www/essenciagua/idsystem/commandes" -ARCHIVEDIR

