#!/bin/bash

# Colori
VERDE='\033[0;32m'
ROSSO='\033[0;31m'
GIALLO='\033[1;33m'
RESET='\033[0m'

# Funzione per gestire i conflitti
handle_conflict() {
    echo -e "${ROSSO}✖ CONFLITTO RILEVATO!${RESET}"
    echo -e "${GIALLO}Passaggi necessari:${RESET}"
    echo "1. Risolvi i conflitti in VS Code."
    echo "2. Esegui 'git add .' per i file risolti."
    echo "3. Rilancia questo script (./update_repo.sh) per continuare."
    exit 1
}

# 1. Controllo se c'è un rebase già in corso
if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ]; then
    echo -e "${GIALLO}--- Rebase in corso rilevato! Provo a continuare... ---${RESET}"
    if git rebase --continue; then
        echo -e "${VERDE}✔ Rebase continuato e finito con successo!${RESET}"
    else
        handle_conflict
    fi
else
    # 2. Inizio normale: Controllo modifiche non salvate
    if [[ -n $(git status -s) ]]; then
        echo -e "${ROSSO}ERRORE: Hai modifiche non salvate.${RESET}"
        echo "Esegui 'git stash' o un commit prima di continuare."
        exit 1
    fi

    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    echo -e "${VERDE}--- Inizio nuovo aggiornamento su branch: $BRANCH ---${RESET}"
    
    git fetch upstream
    if git rebase upstream/$BRANCH; then
        echo -e "${VERDE}✔ Rebase completato senza intoppi!${RESET}"
    else
        handle_conflict
    fi
fi

# 3. Se arriviamo qui, il rebase è finito. Facciamo il push.
echo -e "${VERDE}3. Invio le modifiche al tuo GitHub (Force Push)...${RESET}"
git push origin $(git rev-parse --abbrev-ref HEAD) --force

echo -e "${VERDE}--- TUTTO AGGIORNATO! ---${RESET}"