#!/bin/bash

# GeoTracker - Instalacijska skripta
# Autor: Tvoje Ime

echo "=== POČETAK INSTALACIJE GEOTRACKER PROJEKTA ==="

# 1. Provjera i instalacija sistemskih paketa (Debian/Ubuntu)
echo "[1/4] Provjera sistemskih paketa..."
if ! command -v psql &> /dev/null
then
    echo "PostgreSQL nije instaliran. Pokušavam instalirati..."
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib postgis python3-pip python3-venv
else
    echo "PostgreSQL je već instaliran."
fi

# 2. Postavljanje Python okruženja
echo "[2/4] Postavljanje Python virtualnog okruženja..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "Virtual environment kreiran."
fi

source venv/bin/activate
echo "Instaliranje Python paketa iz requirements.txt..."
pip install -r requirements.txt

# 3. Kreiranje Baze Podataka
echo "[3/4] Konfiguracija baze podataka..."
# Napomena: Ovo traži unos lozinke za 'postgres' korisnika
# Kreira korisnika i bazu ako ne postoje

read -p "Unesite korisničko ime za Postgres (default: postgres): " DB_USER
DB_USER=${DB_USER:-postgres}
read -s -p "Unesite lozinku za Postgres korisnika $DB_USER: " DB_PASS
echo ""

export PGPASSWORD=$DB_PASS

# Kreiraj bazu samo ako ne postoji
if psql -U $DB_USER -lqt | cut -d \| -f 1 | grep -qw geotracker; then
    echo "Baza 'geotracker' već postoji."
else
    echo "Kreiram bazu 'geotracker'..."
    createdb -U $DB_USER geotracker
    
    echo "Uključujem PostGIS ekstenziju..."
    psql -U $DB_USER -d geotracker -c "CREATE EXTENSION IF NOT EXISTS postgis;"
    
    echo "Uvozim strukturu tablica..."
    psql -U $DB_USER -d geotracker -f database/schema.sql
    
    echo "Uvozim napredne objekte (Procedure, View)..."
    psql -U $DB_USER -d geotracker -f database/objects.sql
    
    echo "Generiram testne podatke..."
    psql -U $DB_USER -d geotracker -c "CALL generiraj_testne_podatke(15.97, 45.81, 10);"
fi

# 4. Završetak
echo "[4/4] Instalacija završena!"
echo "------------------------------------------------"
echo "Za pokretanje aplikacije:"
echo "1. source venv/bin/activate"
echo "2. python app.py"
echo "3. Otvorite browser na http://127.0.0.1:5000"
echo "------------------------------------------------"