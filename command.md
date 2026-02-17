set "FLOW_EXE=F:\LGI\Gestcom\Flow.exe"
set "DB_NAME=idsystem.db"
set "USR=LBCScript"
set "PWDC=hfnS02e2F6EvV/A"
set "DBN=ESSENCIAGUA"
set "FTP_PATH=/upload/ess_commandes_export"
set "IMPORT_PATH=F:\LBCScripts\imports2\shopify"
set "PROFIL=Shopify"
set "API_BASE=https://lesbonneschoses.app/oms2"

F:\LGI\Gestcom\Flow.exe -DBN ESSENCIAGUA -USR LBCScript -PWDC hfnS02e2F6EvV/A -SKLOG -FCTN IMPORTORDER -NOFTP 3 -FTPPATH "/upload/ess_commandes_export/" -PATH "F:\LBCScripts\imports2\shopify\"

F:\LGI\Gestcom\Flow.exe -DBN ESSENCIAGUA -USR LBCScript -PWDC hfnS02e2F6EvV/A -SKLOG -FCTN IMPORTORDER -AUTO 1 -PATH "F:\LBCScripts\imports2\shopify\" -WITHWS -NOFTP 3 -FTPPATH "/upload/ess_commandes_export/" -PROFIL "Shopify"

F:\LGI\Gestcom\Flow.exe -DBN ESSENCIAGUA -USR LBCScript -PWDC hfnS02e2F6EvV/A -SKLOG -FCTN IMPORTORDER -PATH "F:\LBCScripts\imports2\commandes\" -NOFTP 5  -FTPPATH "/comexport" -PROFIL "Prestashop"

F:\LGI\Gestcom\Flow.exe -DBN ESSENCIAGUA -USR LBCScript -PWDC hfnS02e2F6EvV/A -SKLOG -FCTN IMPORTORDER -PATH "F:\LBCScripts\imports2\commandes\" -PROFIL "Prestashop"

F:\LGI\Gestcom\Flow.exe -DBN ESSENCIAGUA -USR LBCScript -PWDC hfnS02e2F6EvV/A -SKLOG -FCTN IMPORTCUSTOMER -PATH "F:\LBCScripts\imports2\commandes\" -PROFIL "Prestashop"


'IMPORTORDER'	Import Commande Vente	-AUTO 1
-PATH +Valeur
-WITHWS
-NOFTP +Valeur
-FTPPATH +Valeur
-PROFIL +Valeur

Tasks 
-DBN "ESSENCIAGUA" -USR "LBCScript" -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN EXPORTARTICLE -PATH "F:\LBCScripts\exports2\articles" -NOFTP 5 -FTPPATH "/ess_articles" -FILTRE "ARTDATEL>='Today'-7"

-DBN "ESSENCIAGUA" -USR "LBCScript"  -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN EXPORTARTICLE -PATH "F:\LBCScripts\exports2\stocks" -XMLFILE Stock -NOFTP 5 -FTPPATH "/ess_stocks"

F:\Lgi\GestCom\FloW.exe -DBN "ESSENCIAGUA" -USR "LBCScript"  -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN EXPORTCUSTOMER -PATH "F:\LBCScripts\exports2\clients" -NOFTP 5 -FTPPATH "/ess_clients"  -FILTRE "CUSDATEL>='Today'-7"

-DBN "ESSENCIAGUA" -USR "LBCScript" -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN FREEEXPORTORDER -FILTRE "ORDENTRYDATE>='Today'-7" -PATH "F:\LBCScripts\exports2\commandes"

-DBN "ESSENCIAGUA" -USR "LBCScript" -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN  FTPDIRUPLOAD -LOCALDIR "F:\LBCScripts\exports2\commandes\*.csv" -NOFTP 5 -FTPPATH "/ess_commandes" -ARCHIVEDIR