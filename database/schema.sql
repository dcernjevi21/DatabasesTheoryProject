-- 1. Kreiranje baze (ako već nije kreirana)
-- CREATE DATABASE geotracker;
-- \c geotracker;

-- 2. Uključivanje PostGIS ekstenzije (OBAVEZNO)
CREATE EXTENSION IF NOT EXISTS postgis;

-- 3. Tablica Kategorija (Šifarnik)
CREATE TABLE kategorija (
    id SERIAL PRIMARY KEY,
    naziv VARCHAR(50) NOT NULL UNIQUE,
    opis TEXT,
    ikona_url VARCHAR(255) -- putanja do sličice markera
);

-- Unosimo nekoliko testnih kategorija odmah
INSERT INTO kategorija (naziv, opis) VALUES 
('Priroda', 'Parkovi, planine, rijeke'),
('Kultura', 'Muzeji, galerije, spomenici'),
('Hrana', 'Restorani i barovi'),
('Ostalo', 'Nekategorizirano');

-- 4. Tablica Lokacija (Srce sustava)
CREATE TABLE lokacija (
    id SERIAL PRIMARY KEY,
    naziv VARCHAR(100) NOT NULL,
    opis TEXT,
    datum_posjeta DATE DEFAULT CURRENT_DATE,
    ocjena INTEGER CHECK (ocjena >= 1 AND ocjena <= 5),
    kategorija_id INTEGER REFERENCES kategorija(id) ON DELETE SET NULL,
    
    -- OVO JE KLJUČNO: Prostorni stupac
    -- Tip: Geometrija, Podtip: Točka, Sustav: 4326 (WGS84)
    geom GEOMETRY(Point, 4326) NOT NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Kreiranje Prostornog Indeksa (Zahtjev projekta za optimizaciju)
-- GIST indeks drastično ubrzava prostorne upite
CREATE INDEX idx_lokacija_geom ON lokacija USING GIST (geom);

-- 6. Jednostavna tablica za rute (ako stigneš implementirati linije)
CREATE TABLE ruta (
    id SERIAL PRIMARY KEY,
    naziv VARCHAR(100),
    geom GEOMETRY(LineString, 4326)
);