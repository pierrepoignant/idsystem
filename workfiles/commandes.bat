del /Q "F:\LBCScripts\exports2\commandes\*.csv"

F:\Lgi\GestCom\FloW.exe -DBN "ESSENCIAGUA" -USR "LBCScript" -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN EXPORTARTICLE -PATH "F:\LBCScripts\exports2\articles" -NOFTP 3 -FTPPATH "/upload/ess_articles" -FILTRE "ARTDATEL>='Today'-7"

F:\Lgi\GestCom\FloW.exe -DBN "ESSENCIAGUA" -USR "LBCScript"  -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN EXPORTARTICLE -PATH "F:\LBCScripts\exports2\stocks" -XMLFILE Stock -NOFTP 3 -FTPPATH "/upload/ess_stocks"

F:\Lgi\GestCom\FloW.exe -DBN "ESSENCIAGUA" -USR "LBCScript"  -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN EXPORTCUSTOMER -PATH "F:\LBCScripts\exports2\clients" -NOFTP 3 -FTPPATH "/upload/ess_clients"  -FILTRE "CUSDATEL>='Today'-7"

F:\Lgi\GestCom\FloW.exe -DBN "ESSENCIAGUA" -USR "LBCScript"  -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN FREEEXPORTORDER -FILTRE "ORDENTRYDATE>='Today'-7" -PATH "F:\LBCScripts\exports2\commandes"

F:\Lgi\GestCom\FloW.exe -DBN "ESSENCIAGUA" -USR "LBCScript"  -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN  FTPDIRUPLOAD -LOCALDIR "F:\LBCScripts\exports2\commandes\*.csv" -NOFTP 3 -FTPPATH "/upload/ess_commandes" -ARCHIVEDIR