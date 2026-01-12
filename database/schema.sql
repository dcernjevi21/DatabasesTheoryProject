DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- ==========================================
-- 1. TABLICE I PREDIKATI (CONSTRAINTS)
-- ==========================================

CREATE TABLE regija (
    id SERIAL PRIMARY KEY,
    naziv VARCHAR(100),
    geom GEOMETRY(Polygon, 4326)
);

CREATE TABLE kategorija (
    id SERIAL PRIMARY KEY,
    naziv VARCHAR(50),
    boja VARCHAR(20)
);

CREATE TABLE klub (
    id SERIAL PRIMARY KEY,
    naziv VARCHAR(100) NOT NULL,
    adresa VARCHAR(150),
    regija_id INTEGER REFERENCES regija(id),
    geom GEOMETRY(Point, 4326),
    tsv tsvector
);

CREATE TABLE gaza (
    id SERIAL PRIMARY KEY,
    klub_id INTEGER REFERENCES klub(id) ON DELETE CASCADE,
    kategorija_id INTEGER REFERENCES kategorija(id),
    datum_nastupa DATE NOT NULL,
    honorar NUMERIC(10, 2) DEFAULT 0,
    troskovi NUMERIC(10, 2) DEFAULT 0,
    opis TEXT,
    zakljucano BOOLEAN DEFAULT FALSE, -- Za proceduru zakljucavanja
    
    -- CHECK CONSTRAINTS (Sigurnost podataka)
    CONSTRAINT chk_financije_pozitivne CHECK (honorar >= 0 AND troskovi >= 0),
    CONSTRAINT chk_datum_validan CHECK (datum_nastupa > '2020-01-01')
);

CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    gaza_id INTEGER,
    stari_honorar NUMERIC,
    novi_honorar NUMERIC,
    korisnik VARCHAR DEFAULT current_user,
    vrijeme_izmjene TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indeksi
CREATE INDEX idx_klub_geom ON klub USING GIST (geom);
CREATE INDEX idx_regija_geom ON regija USING GIST (geom);