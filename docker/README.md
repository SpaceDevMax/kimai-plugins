# Docker & MySQL
Diese Anleitung beschreibt, wie du [Kimai](https://github.com/kimai/kimai) mit Docker und MySQL einrichtest. Die Konfiguration verwendet zwei Docker-Container (MySQL und Kimai) auf einem gemeinsamen Netzwerk. Am Ende hast du eine laufende Kimai-Instanz unter `http://localhost:8001` mit einem Admin-Benutzer.

## Voraussetzungen
- **Docker**: Installiert und laufend (z. B. Docker Desktop auf Mac/Windows oder Docker auf Linux).
- **Git**: Zum Klonen des Repositories.
- **Terminal**: Für Docker-Befehle oder das Setup-Skript.
- **Browser**: Zum Zugriff auf die Kimai-Oberfläche.

## Schnellstart mit Skript
Für die einfachste Einrichtung nutze das mitgelieferte Bash-Skript `setup-kimai.sh`:

```bash
git clone https://github.com/SpaceDevMax/kimai-plugins.git
cd kimai-plugins/docker
chmod +x setup-kimai.sh
sudo ./setup-kimai.sh
```

Das Skript erstellt das Netzwerk, startet MySQL und Kimai, und führt dich durch die Erstellung eines Admin-Benutzers. Folge den Anweisungen im Terminal.

## Manuelle Installation

### 1. Docker-Netzwerk erstellen
Erstelle ein Netzwerk für die Kommunikation zwischen MySQL und Kimai:

```bash
docker network create kimai-net
```

### 2. MySQL-Container starten
Starte einen MySQL-Container mit der Datenbank `kimai`:

```bash
docker run --rm --name kimai-mysql-testing \
    -e MYSQL_DATABASE=kimai \
    -e MYSQL_USER=kimai \
    -e MYSQL_PASSWORD=kimai \
    -e MYSQL_ROOT_PASSWORD=kimai \
    --network kimai-net \
    -d mysql
```

- **Optionen**:
  - `--rm`: Entfernt den Container nach dem Stoppen.
  - `--name kimai-mysql-testing`: Container-Name.
  - `-e`: Setzt Umgebungsvariablen für Datenbank und Benutzer.
  - `--network kimai-net`: Verbindet den Container mit dem Netzwerk.
  - `-d`: Startet im Hintergrund.
- **Überprüfung**:
  Warte 10 Sekunden und prüfe die Logs:
  ```bash
  docker logs kimai-mysql-testing
  ```
  Suche nach „ready for connections“.

### 3. Kimai-Container starten
Starte den Kimai-Container mit der Datenbankverbindung:

```bash
docker run --rm --name kimai-test \
    -ti \
    -p 8001:8001 \
    -e DATABASE_URL=mysql://kimai:kimai@kimai-mysql-testing:3306/kimai \
    --network kimai-net \
    kimai/kimai2:apache
```

- **Optionen**:
  - `-ti`: Interaktiver Modus mit Terminal.
  - `-p 8001:8001`: Bindet Port 8001 an den Host.
  - `-e DATABASE_URL`: Verbindet zu MySQL (Benutzer: `kimai`, Passwort: `kimai`, Host: `kimai-mysql-testing`, Port: `3306`).
  - `kimai/kimai2:apache`: Offizielles Kimai-Image.
- **Überprüfung**:
  Prüfe die Logs:
  ```bash
  docker logs kimai-test
  ```
  Suche nach „Successfully installed Kimai version“ und keine `SQLSTATE[HY000]`-Fehler. Teste den Zugriff:
  ```bash
  curl -L http://localhost:8001
  ```
  Öffne `http://localhost:8001` im Browser (Login-Seite).

### 4. Admin-Benutzer erstellen
Erstelle einen Admin-Benutzer:

```bash
docker exec -ti kimai-test \
    /opt/kimai/bin/console \
    kimai:user:create admin admin@example.com ROLE_SUPER_ADMIN
```

- Gib ein sicheres Passwort ein.
- **Alternative (nicht-interaktiv)**:
  Falls unterstützt (prüfe mit `kimai:user:create --help`):
  ```bash
  docker exec -ti kimai-test \
      /opt/kimai/bin/console \
      kimai:user:create admin admin@example.com ROLE_SUPER_ADMIN --password=dein_sicheres_passwort
  ```
- **Überprüfung**:
  Liste Benutzer auf:
  ```bash
  docker exec -ti kimai-test /opt/kimai/bin/console kimai:user:list
  ```
  Melde dich unter `http://localhost:8001` mit `admin` und dem Passwort an.

### 5. Kimai mit Plugins verwenden
- **Webzugriff**: Öffne `http://localhost:8001`, melde dich an und starte die Zeiterfassung.
- **Container stoppen**:
  ```bash
  docker stop kimai-mysql-testing kimai-test
  ```



## Hinweise
- **Datenpersistenz**: Ohne Volumes gehen Daten verloren. Für Produktion:
  ```bash
  -v kimai-mysql-data:/var/lib/mysql
  ```
- **Sicherheit**: Verwende starke Passwörter und speichere sie in einer `.env`-Datei.
- **Version**: Nutzt Kimai 2.36.1 (`kimai/kimai2:apache`). Für andere Versionen, z. B.:
  ```bash
  kimai/kimai2:2.36.1-apache
  ```

## Fehlerbehebung
- **Datenbankverbindung**:
  - Prüfe Logs: `docker logs kimai-mysql-testing`.
  - Teste Verbindung:
    ```bash
    docker exec -ti kimai-test mysql -u kimai -pkimai -h kimai-mysql-testing -P 3306 -e "SELECT 1"
    ```
- **Login-Probleme**:
  - Prüfe Logs: `docker logs kimai-test` und `/opt/kimai/var/log/prod.log`.
- **Issues**: Erstelle ein Issue in diesem Repository.
