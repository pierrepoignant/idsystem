REM Import clients
"F:\LGI\Gestcom\Flow.exe" -DBN "ESSENCIAGUA" -USR "LBCScript" -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN IMPORTCUSTOMER -NOFTP 3 -FTPPATH "/upload/ess_clients_export" -PATH "F:\LBCScripts\imports2\clients"

REM Import Commandes
"F:\LGI\Gestcom\Flow.exe" -DBN "ESSENCIAGUA" -USR "LBCScript" -PWDC "hfnS02e2F6EvV/A" -SKLOG -FCTN IMPORTORDER -NOFTP 2 -FTPPATH "/upload/ess_commandes_export" -PROFIL Shopify -PATH "F:\LBCScripts\imports2\shopify"