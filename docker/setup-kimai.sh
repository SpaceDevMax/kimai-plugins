#!/bin/bash

# setup-kimai.sh
# Automatisiert die Einrichtung von Custom Kimai mit Docker (MySQL + Kimai)
# Erstellt Netzwerk, startet Container und fügt einen Admin-Benutzer hinzu

set -e # Beende Skript bei Fehlern

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Variablen
NETWORK="kimai-net"
MYSQL_CONTAINER="kimai-mysql-testing"
KIMAI_CONTAINER="kimai-test"
KIMAI_PORT="8001"
ADMIN_USER="admin"
ADMIN_EMAIL="admin@example.com"
ADMIN_ROLE="ROLE_SUPER_ADMIN"

echo "=== Custom Kimai Einrichtung ==="

# 1. Prüfe, ob Docker läuft
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Fehler: Docker ist nicht gestartet oder nicht installiert.${NC}"
    exit 1
fi

# 2. Erstelle Docker-Netzwerk (falls nicht vorhanden)
if ! docker network ls | grep -q "$NETWORK"; then
    echo "Erstelle Docker-Netzwerk '$NETWORK'..."
    docker network create "$NETWORK"
    echo -e "${GREEN}Netzwerk erstellt.${NC}"
else
    echo "Netzwerk '$NETWORK' existiert bereits."
fi

# 3. Stoppe und entferne bestehende Container (falls vorhanden)
for container in "$MYSQL_CONTAINER" "$KIMAI_CONTAINER"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "Stoppe und entferne bestehenden Container '$container'..."
        docker stop "$container" >/dev/null
        docker rm "$container" >/dev/null
    fi
done

# 4. Starte MySQL-Container
echo "Starte MySQL-Container '$MYSQL_CONTAINER'..."
docker run --rm --name "$MYSQL_CONTAINER" \
    -e MYSQL_DATABASE=kimai \
    -e MYSQL_USER=kimai \
    -e MYSQL_PASSWORD=kimai \
    -e MYSQL_ROOT_PASSWORD=kimai \
    --network "$NETWORK" \
    -d mysql

# Warte, bis MySQL bereit ist (max. 30 Sekunden)
echo "Warte auf MySQL-Initialisierung..."
for i in {1..30}; do
    if docker logs "$MYSQL_CONTAINER" 2>&1 | grep -q "ready for connections"; then
        echo -e "${GREEN}MySQL ist bereit.${NC}"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo -e "${RED}Fehler: MySQL nicht bereit nach 30 Sekunden.${NC}"
        docker logs "$MYSQL_CONTAINER"
        exit 1
    fi
    sleep 1
done

# 5. Starte Kimai-Container
echo "Starte Kimai-Container '$KIMAI_CONTAINER'..."
docker run --rm --name "$KIMAI_CONTAINER" \
    -d \
    -p "$KIMAI_PORT:8001" \
    -e DATABASE_URL=mysql://kimai:kimai@kimai-mysql-testing:3306/kimai \
    --network "$NETWORK" \
    kimai/kimai2:apache

# Warte, bis Kimai installiert ist (max. 60 Sekunden)
echo "Warte auf Kimai-Installation..."
for i in {1..60}; do
    if docker logs "$KIMAI_CONTAINER" 2>&1 | grep -q "Successfully installed Kimai version"; then
        echo -e "${GREEN}Kimai ist installiert.${NC}"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo -e "${RED}Fehler: Kimai nicht installiert nach 60 Sekunden.${NC}"
        docker logs "$KIMAI_CONTAINER"
        exit 1
    fi
    sleep 1
done

# 6. Erstelle Admin-Benutzer
echo "Erstelle Admin-Benutzer '$ADMIN_USER'..."
echo "Bitte gib ein sicheres Passwort ein (wird im Terminal nicht angezeigt):"
read -s ADMIN_PASSWORD
if [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${RED}Fehler: Passwort darf nicht leer sein.${NC}"
    exit 1
fi

# Führe Benutzererstellung aus
docker exec "$KIMAI_CONTAINER" \
    /opt/kimai/bin/console \
    kimai:user:create "$ADMIN_USER" "$ADMIN_EMAIL" "$ADMIN_ROLE" <<< "$ADMIN_PASSWORD"

# Überprüfe, ob Benutzer erstellt wurde
if docker exec "$KIMAI_CONTAINER" /opt/kimai/bin/console kimai:user:list | grep -q "$ADMIN_USER"; then
    echo -e "${GREEN}Admin-Benutzer '$ADMIN_USER' erfolgreich erstellt.${NC}"
else
    echo -e "${RED}Fehler: Admin-Benutzer konnte nicht erstellt werden.${NC}"
    docker logs "$KIMAI_CONTAINER"
    exit 1
fi

# 7. Abschluss
echo -e "\n=== Einrichtung abgeschlossen ==="
echo "Kimai läuft unter: http://localhost:$KIMAI_PORT"
echo "Melde dich mit Benutzer '$ADMIN_USER' und deinem Passwort an."
echo -e "\nUm die Container zu stoppen:"
echo "  docker stop $MYSQL_CONTAINER $KIMAI_CONTAINER"
echo -e "\nUm deine Erweiterungen zu entwickeln, siehe README.md."
