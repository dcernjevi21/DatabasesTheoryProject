#!/bin/bash

# Generirano pomoću AI

# Prekini skriptu ako bilo koja naredba javi grešku
set -e

echo "=== DJ TOUR MANAGER PRO - INSTALACIJA ==="

# ---------------------------------------------------------
# 1. INSTALACIJA SUSTAVSKIH PAKETA
# ---------------------------------------------------------
echo "[1/6] Provjera sistemskih paketa..."
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
echo "[2/6] Postavljanje Python virtualnog okruženja..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "Virtual environment kreiran."
else
    echo "Virtual environment već postoji."
fi

source venv/bin/activate

if [ -f "requirements.txt" ]; then
    echo "Instaliram Python biblioteke iz requirements.txt..."
    pip install -r requirements.txt
else
    echo "UPOZORENJE: requirements.txt nije pronađen! Instaliram ručno..."
    pip install Flask Flask-SQLAlchemy psycopg2-binary GeoAlchemy2
fi

# ---------------------------------------------------------
# 3. PROVJERA SQL DATOTEKA
# ---------------------------------------------------------
echo "[3/6] Provjera datoteka baze podataka..."

if [ ! -f "database/schema.sql" ]; then
    echo "GREŠKA: Nedostaje 'database/schema.sql'!"
    exit 1
fi

if [ ! -f "database/logic.sql" ]; then
    echo "GREŠKA: Nedostaje 'database/logic.sql'!"
    exit 1
fi

echo "Pronađene datoteke: schema.sql i logic.sql."

# ---------------------------------------------------------
# 4. KONFIGURACIJA KONEKCIJE
# ---------------------------------------------------------
echo "[4/6] Konfiguracija baze podataka..."

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
# 5. UVOZ STRUKTURE (SCHEMA)
# ---------------------------------------------------------
echo "[5/6] Uvozim strukturu tablica (Schema)..."
psql -U "$DB_USER" -d geotracker -f database/schema.sql

# ---------------------------------------------------------
# 6. UVOZ LOGIKE I PODATAKA (LOGIC)
# ---------------------------------------------------------
echo "[6/6] Uvozim funkcije, triggere, podatke itd..."
psql -U "$DB_USER" -d geotracker -f database/logic.sql

echo ""
echo "========================================="
echo "   INSTALACIJA USPJEŠNO ZAVRŠENA!      "
echo "========================================="
echo "Za pokretanje aplikacije upišite:"
echo "  source venv/bin/activate"
echo "  python app.py"
echo "Pristupite aplikaciji na adresu koja se ispiše u konzoli, npr.: http://127.0.0.1:5000
echo "========================================="