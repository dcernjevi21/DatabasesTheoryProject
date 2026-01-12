#!/bin/bash

echo "=== DJ TOUR MANAGER PRO - INSTALACIJA ==="

# 1. Provjera PostgreSQL-a
if ! command -v psql &> /dev/null; then
    echo "Instaliram PostgreSQL i PostGIS..."
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-contrib postgis python3-pip python3-venv
fi

# 2. Python Okruženje
echo "Postavljam Python venv..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install Flask Flask-SQLAlchemy psycopg2-binary GeoAlchemy2

# 3. Baza Podataka
read -p "Unesite korisnika baze (default: postgres): " DB_USER
DB_USER=${DB_USER:-postgres}
read -s -p "Unesite lozinku za $DB_USER: " DB_PASS
echo ""

export PGPASSWORD=$DB_PASS

# Kreiraj bazu ako ne postoji
psql -U $DB_USER -tc "SELECT 1 FROM pg_database WHERE datname = 'geotracker'" | grep -q 1 || psql -U $DB_USER -c "CREATE DATABASE geotracker"

echo "Uvozim SQL shemu i podatke..."
# Ovdje pretpostavljamo da je tvoj SQL kod spremljen u database/schema.sql
psql -U $DB_USER -d geotracker -f database/schema.sql

echo "=== GOTOVO! ==="
echo "Pokrenite sa: source venv/bin/activate && python app.py"