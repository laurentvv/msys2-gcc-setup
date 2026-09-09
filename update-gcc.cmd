@echo off
rem =============================================================================
rem  update-gcc.cmd — Lanceur Windows pour la mise a jour du compilateur GCC.
rem
rem  Utilisable en double-clic, en ligne de commande ou dans le Planificateur
rem  de taches Windows. Les options passees sont transmises au script bash
rem  (--check, --yes, --full, --quiet, --news).
rem
rem  Exemple de planification hebdomadaire (chaque lundi a 07:00) :
rem     schtasks /Create /TN "Mise a jour GCC" /SC WEEKLY /D MON /ST 07:00 /TR "C:\msys64\update-gcc.cmd"
rem  Pour une mise a jour entierement automatique, planifiez :
rem     C:\msys64\update-gcc.cmd --yes --quiet
rem =============================================================================
"C:\msys64\usr\bin\bash.exe" -lc "/usr/local/bin/update-gcc %*"
