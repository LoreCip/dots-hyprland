#!/bin/bash

# Colori
VERDE='\033[0;32m'
ROSSO='\033[0;31m'
GIALLO='\033[1;33m'
RESET='\033[0m'

# 1. Verifica che la directory sia pulita
if [[ -n $(git status -s) ]]; then
    echo -e "${ROSSO}ERRORE: Hai modifiche non salvate (uncommitted).${RESET}"
    echo "Salvale o mettile in stash (git stash) prima di continuare."
    exit 1
fi

# 2. Controllo upstream
if ! git remote | grep -q "upstream"; then
    echo -e "${ROSSO}ERRORE: Remote 'upstream' non trovato.${RESET}"
    exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
BACKUP_BRANCH="backup-aggiornamento-$(date +%Y%m%d-%H%M%S)"

echo -e "${GIALLO}--- Preparazione aggiornamento ---${RESET}"

# 3. Creazione backup di sicurezza
echo -e "${VERDE}Creazione branch di backup: $BACKUP_BRANCH${RESET}"
git branch $BACKUP_BRANCH

# 4. Fetch e Rebase
echo -e "${VERDE}Scarico aggiornamenti e inizio Rebase...${RESET}"
git fetch upstream

if git rebase upstream/$BRANCH; then
    echo -e "${VERDE}✔ Rebase completato senza conflitti!${RESET}"
else
    echo -e "${ROSSO}✖ CONFLITTI RILEVATI!${RESET}"
    echo -e "${GIALLO}-------------------------------------------------------"
    echo -e "1. Apri VS Code: i file in conflitto sono evidenziati in rosso."
    echo -e "2. Usa l'interfaccia 'Source Control' per accettare le modifiche."
    echo -e "3. Una volta risolti tutti i file, esegui nel terminale:"
    echo -e "   git add . && git rebase --continue"
    echo -e "4. Se vuoi annullare tutto: git rebase --abort"
    echo -e "-------------------------------------------------------${RESET}"
    exit 1
fi

# 5. Push finale (solo se il rebase è andato liscio al primo colpo)
echo -e "${VERDE}Invio al tuo repository GitHub...${RESET}"
git push origin $BRANCH --force

echo -e "${VERDE}--- AGGIORNAMENTO COMPLETATO! ---${RESET}"