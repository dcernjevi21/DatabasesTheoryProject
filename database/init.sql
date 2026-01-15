DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE TABLE regija (
    id SERIAL PRIMARY KEY,
    naziv VARCHAR(100),
    geom GEOMETRY(MultiPolygon, 4326) 
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
    zakljucano BOOLEAN DEFAULT FALSE,
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


-- Funkcije
CREATE OR REPLACE FUNCTION izracunaj_profit(honorar NUMERIC, troskovi NUMERIC)
RETURNS NUMERIC AS $$
BEGIN
    RETURN honorar - troskovi; 
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ukupni_km_mjeseca(mjesec VARCHAR)
RETURNS FLOAT AS $$
DECLARE 
    linija GEOMETRY;
BEGIN
    SELECT ST_MakeLine(k.geom ORDER BY g.datum_nastupa) INTO linija
    FROM gaza g JOIN klub k ON g.klub_id = k.id
    WHERE to_char(g.datum_nastupa, 'YYYY-MM') = mjesec;

    IF linija IS NULL OR ST_NumPoints(linija) < 2 THEN RETURN 0; END IF;
    RETURN ST_Length(linija::geography) / 1000.0;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_monthly_route(mjesec VARCHAR) RETURNS JSON AS $$
DECLARE geo JSON;
BEGIN
    SELECT ST_AsGeoJSON(ST_MakeLine(k.geom ORDER BY g.datum_nastupa))::json INTO geo
    FROM gaza g JOIN klub k ON g.klub_id = k.id WHERE to_char(g.datum_nastupa, 'YYYY-MM') = mjesec;
    RETURN geo;
END;
$$ LANGUAGE plpgsql;


-- Okidači
CREATE OR REPLACE FUNCTION trg_klub_regija() RETURNS TRIGGER AS $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT id, geom FROM regija LOOP
        IF ST_Intersects(r.geom, NEW.geom) THEN
            NEW.regija_id := r.id; EXIT;
        END IF;
    END LOOP;
    NEW.tsv := to_tsvector('simple', unaccent(NEW.naziv || ' ' || COALESCE(NEW.adresa, '')));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_klub_insert BEFORE INSERT OR UPDATE ON klub FOR EACH ROW EXECUTE FUNCTION trg_klub_regija();

CREATE OR REPLACE FUNCTION trg_audit_honorar_func() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.honorar <> NEW.honorar THEN
        INSERT INTO audit_log (gaza_id, stari_honorar, novi_honorar)
        VALUES (OLD.id, OLD.honorar, NEW.honorar);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_audit_honorar AFTER UPDATE ON gaza FOR EACH ROW EXECUTE FUNCTION trg_audit_honorar_func();

CREATE OR REPLACE FUNCTION trg_check_locked() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.zakljucano = TRUE AND (NEW.zakljucano = TRUE) THEN
       RAISE EXCEPTION 'Ova gaža je zaključana i ne može se mijenjati!';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_prevent_update BEFORE UPDATE ON gaza FOR EACH ROW WHEN (OLD.zakljucano IS TRUE) EXECUTE FUNCTION trg_check_locked();


-- Procedure
CREATE OR REPLACE PROCEDURE zakljucaj_mjesec(mjesec_str VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE gaza 
    SET zakljucano = TRUE 
    WHERE to_char(datum_nastupa, 'YYYY-MM') = mjesec_str;
END;
$$;


-- Pogledi
CREATE OR REPLACE VIEW view_statistika_mjesec AS
SELECT 
    to_char(g.datum_nastupa, 'YYYY-MM') as id_mjeseca,
    COUNT(*) as broj_gaza,
    SUM(g.honorar) as prihod,
    SUM(g.troskovi) as trosak,
    SUM(izracunaj_profit(g.honorar, g.troskovi)) as profit
FROM gaza g
GROUP BY to_char(g.datum_nastupa, 'YYYY-MM');

CREATE OR REPLACE VIEW view_top_klubovi AS
SELECT 
    k.naziv,
    r.naziv as regija,
    COUNT(g.id) as broj_nastupa,
    SUM(g.honorar - g.troskovi) as ukupni_profit
FROM klub k
JOIN gaza g ON k.id = g.klub_id
LEFT JOIN regija r ON k.regija_id = r.id
GROUP BY k.id, k.naziv, r.naziv
ORDER BY ukupni_profit DESC;

CREATE OR REPLACE VIEW view_dostupni_mjeseci AS
SELECT DISTINCT to_char(datum_nastupa, 'YYYY-MM') as id, to_char(datum_nastupa, 'TMMonth YYYY') as naziv 
FROM gaza ORDER BY id DESC;