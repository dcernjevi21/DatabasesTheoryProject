#!/bin/bash

# Generirano pomoću AI

# Prekini skriptu ako bilo koja naredba javi grešku
set -e

echo "=== DJ TOUR MANAGER - INSTALACIJA ==="

# ---------------------------------------------------------
# 1. INSTALACIJA SUSTAVSKIH PAKETA
# ---------------------------------------------------------
echo "[1/7] Provjera sistemskih paketa..."
if ! command -v psql &> /dev/null; then
    echo "PostgreSQL nije detektiran. Instaliram potrebne pakete..."
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib postgis python3-pip python3-venv libpq-dev
else
    echo "PostgreSQL je već instaliran."
fi

# ---------------------------------------------------------
# 2. PRIPREMA PYTHON OKRUŽENJA
# ---------------------------------------------------------
echo "[2/7] Postavljanje Python virtualnog okruženja..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "Virtual environment kreiran."
else
    echo "Virtual environment već postoji."
fi

source venv/bin/activate

# Instalacija paketa
if [ -f "requirements.txt" ]; then
    echo "Instaliram Python biblioteke iz requirements.txt..."
    pip install -r requirements.txt
else
    echo "UPOZORENJE: requirements.txt nije pronađen! Instaliram ručno osnovne pakete..."
    pip install Flask Flask-SQLAlchemy psycopg2-binary GeoAlchemy2 requests
fi

# ---------------------------------------------------------
# 3. PROVJERA DATOTEKA PROJEKTA
# ---------------------------------------------------------
echo "[3/7] Provjera datoteka..."

if [ ! -f "database/init.sql" ]; then
    echo "GREŠKA: Nedostaje 'database/init.sql'!"
    exit 1
fi

if [ ! -f "import_map.py" ]; then
    echo "GREŠKA: Nedostaje 'import_map.py'!"
    exit 1
fi

if [ ! -f "database/seed_data.sql" ]; then
    echo "GREŠKA: Nedostaje 'database/seed_data.sql'!"
    exit 1
fi

echo "Sve potrebne datoteke su pronađene."

# ---------------------------------------------------------
# 4. KONFIGURACIJA KONEKCIJE
# ---------------------------------------------------------
echo "[4/7] Konfiguracija baze podataka..."

read -p "Unesite korisnika baze (default: postgres): " DB_USER
DB_USER=${DB_USER:-postgres}
read -s -p "Unesite lozinku za $DB_USER: " DB_PASS
echo ""

export PGPASSWORD=$DB_PASS

# Test konekcije
if ! psql -U "$DB_USER" -c '\q' 2>/dev/null; then
    echo "GREŠKA: Ne mogu se spojiti na bazu s korisnikom '$DB_USER'."
    echo "Provjerite lozinku."
    exit 1
fi

# Kreiranje baze ako ne postoji
if psql -U "$DB_USER" -tc "SELECT 1 FROM pg_database WHERE datname = 'geotracker'" | grep -q 1; then
    echo "Baza 'geotracker' već postoji."
else
    echo "Kreiram bazu 'geotracker'..."
    createdb -U "$DB_USER" geotracker
fi

# ---------------------------------------------------------
# 5. KORAK 1: INICIJALIZACIJA BAZE (Tablice, Triggeri...)
# ---------------------------------------------------------
echo "[5/7] Pokrećem init.sql (Kreiranje strukture)..."
psql -U "$DB_USER" -d geotracker -f database/init.sql

# ---------------------------------------------------------
# 6. KORAK 2: IMPORT GEOGRAFSKIH PODATAKA (Python)
# ---------------------------------------------------------
echo "[6/7] Pokrećem import_map.py (Uvoz regija)..."
# Skripta koristi DB_URI varijablu, moramo biti sigurni da je postavljena u samoj python skripti
# ili je možemo proslijediti kao environment varijablu ako python skripta to podržava.
# Pretpostavljamo da je python skripta konfigurirana.
python import_map.py

# ---------------------------------------------------------
# 7. KORAK 3: SEED PODATAKA (Klubovi, Gaže...)
# ---------------------------------------------------------
echo "[7/7] Pokrećem seed_data.sql (Uvoz podataka)..."
psql -U "$DB_USER" -d geotracker -f database/seed_data.sql

echo ""
echo "========================================="
echo "   INSTALACIJA USPJEŠNO ZAVRŠENA!      "
echo "========================================="
echo "Za pokretanje aplikacije upišite:"
echo "  source venv/bin/activate"
echo "  python app.py"
echo "Pristupite aplikaciji na: http://127.0.0.1:5000"
echo "========================================="