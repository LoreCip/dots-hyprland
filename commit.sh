#!/bin/bash
set -e

# Colori per l'output
VERDE='\033[0;32m'
ROSSO='\033[0;31m'
GIALLO='\033[1;33m'
RESET='\033[0m'

read -p "Commit message: " COMMIT
BRANCH=$(git rev-parse --abbrev-ref HEAD)

git add .
git commit -m "$COMMIT"
git push origin $BRANCH

echo -e "${VERDE}--- TUTTO AGGIORNATO! ---${RESET}"
