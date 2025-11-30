#!/bin/bash

# Colori per l'output
VERDE='\033[0;32m'
ROSSO='\033[0;31m'
GIALLO='\033[1;33m'
RESET='\033[0m'

# 1. Controllo preliminare
if ! git remote | grep -q "upstream"; then
    echo -e "${ROSSO}ERRORE: Non hai configurato 'upstream'.${RESET}"
    echo "Esegui prima: git remote add upstream https://github.com/end-4/dots-hyprland.git"
    exit 1
fi

# Ottieni il nome del branch corrente (solitamente main o master)
BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo -e "${GIALLO}--- Inizio aggiornamento del branch: $BRANCH ---${RESET}"

# 2. Scarica le novità dall'autore originale (senza toccare nulla)
echo -e "${VERDE}1. Scarico gli aggiornamenti da upstream...${RESET}"
git fetch upstream

# 3. Esegui il Rebase
echo -e "${VERDE}2. Applico le tue modifiche sopra quelle nuove (Rebase)...${RESET}"
if git rebase upstream/$BRANCH; then
    echo -e "${VERDE}✔ Rebase completato con successo!${RESET}"
else
    echo -e "${ROSSO}✖ CONFLITTO RILEVATO!${RESET}"
    echo -e "${GIALLO}Lo script si è fermato perché c'è un conflitto nei file.${RESET}"
    echo "Cosa devi fare ora:"
    echo "1. Apri i file indicati sopra e risolvi i conflitti manualmente."
    echo "2. Esegui: git add ."
    echo "3. Esegui: git rebase --continue"
    echo "4. Infine lancia: git push origin $BRANCH --force"
    exit 1
fi

# 4. Push forzato sul tuo GitHub
echo -e "${VERDE}3. Invio le modifiche al tuo GitHub (Force Push)...${RESET}"
git push origin $BRANCH --force

echo -e "${VERDE}--- TUTTO AGGIORNATO! ---${RESET}"
echo "Ora puoi lanciare ./setup install per applicare le modifiche al PC."
