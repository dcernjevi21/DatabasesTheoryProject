-- 2. FUNKCIJE I LOGIKA

-- Izračun profita (Jednostavna verzija: Prihod - Trošak)
CREATE OR REPLACE FUNCTION izracunaj_profit(honorar NUMERIC, troskovi NUMERIC)
RETURNS NUMERIC AS $$
BEGIN
    -- Ako želiš bez poreza, samo makni * 0.75
    RETURN honorar - troskovi; 
END;
$$ LANGUAGE plpgsql;

-- TRIGGER: Automatski regija za KLUB (samo jednom se računa)
CREATE OR REPLACE FUNCTION trg_klub_regija()
RETURNS TRIGGER AS $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT id, geom FROM regija LOOP
        IF ST_Intersects(r.geom, NEW.geom) THEN
            NEW.regija_id := r.id;
            EXIT;
        END IF;
    END LOOP;
    NEW.tsv := to_tsvector('simple', unaccent(NEW.naziv || ' ' || COALESCE(NEW.adresa, '')));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_klub_insert
BEFORE INSERT OR UPDATE ON klub
FOR EACH ROW EXECUTE FUNCTION trg_klub_regija();

-- 3. POGLEDI ZA APLIKACIJU

-- View: Dostupni mjeseci (iz tablice GAŽA)
CREATE OR REPLACE VIEW view_dostupni_mjeseci AS
SELECT DISTINCT 
    to_char(datum_nastupa, 'YYYY-MM') as id_mjeseca,
    to_char(datum_nastupa, 'TMMonth YYYY') as naziv_mjeseca
FROM gaza
ORDER BY id_mjeseca DESC;

-- View: Statistika (spaja gažu i klub)
CREATE OR REPLACE VIEW view_statistika_mjesec AS
SELECT 
    to_char(g.datum_nastupa, 'YYYY-MM') as id_mjeseca,
    COUNT(*) as broj_gaza,
    SUM(g.honorar) as prihod,
    SUM(g.troskovi) as trosak,
    SUM(izracunaj_profit(g.honorar, g.troskovi)) as profit
FROM gaza g
GROUP BY to_char(g.datum_nastupa, 'YYYY-MM');

-- Funkcija za rutu mjeseca
CREATE OR REPLACE FUNCTION get_monthly_route(mjesec VARCHAR)
RETURNS JSON AS $$
DECLARE geo JSON;
BEGIN
    SELECT ST_AsGeoJSON(ST_MakeLine(k.geom ORDER BY g.datum_nastupa))::json INTO geo
    FROM gaza g
    JOIN klub k ON g.klub_id = k.id
    WHERE to_char(g.datum_nastupa, 'YYYY-MM') = mjesec;
    RETURN geo;
END;
$$ LANGUAGE plpgsql;

-- 4. SEED DATA
INSERT INTO kategorija (naziv, boja) VALUES ('Klub', '#e74c3c'), ('Festival', '#9b59b6'), ('Bar', '#3498db'), ('Privatni event', '#2ecc71');

-- Unosimo KLUBOVE (Samo jednom!)

INSERT INTO klub (naziv, adresa, geom) VALUES
('Boogaloo', 'Zagreb', ST_SetSRID(ST_MakePoint(15.968, 45.800), 4326)),
('Peti Kupe', 'Zagreb', ST_SetSRID(ST_MakePoint(15.980, 45.802), 4326)),
('Bunker', 'Samobor', ST_SetSRID(ST_MakePoint(15.710, 45.800), 4326)),
('Tufna', 'Osijek', ST_SetSRID(ST_MakePoint(18.694, 45.560), 4326)),
('Epic', 'Osijek', ST_SetSRID(ST_MakePoint(18.680, 45.550), 4326)),
('Crkva', 'Rijeka', ST_SetSRID(ST_MakePoint(14.450, 45.320), 4326)),
('Uljanik', 'Pula', ST_SetSRID(ST_MakePoint(13.850, 44.860), 4326)),
('Steel', 'Rovinj', ST_SetSRID(ST_MakePoint(13.640, 45.080), 4326)),
('Central', 'Split', ST_SetSRID(ST_MakePoint(16.440, 43.510), 4326)),
('Vanilla', 'Split', ST_SetSRID(ST_MakePoint(16.430, 43.520), 4326)),
('Revelin', 'Dubrovnik', ST_SetSRID(ST_MakePoint(18.110, 42.640), 4326)),
('Carpe Diem', 'Hvar', ST_SetSRID(ST_MakePoint(16.430, 43.170), 4326)),
('Papaya', 'Zrće', ST_SetSRID(ST_MakePoint(14.890, 44.540), 4326)),
('Opera', 'Zadar', ST_SetSRID(ST_MakePoint(15.230, 44.110), 4326));

-- 3. UNOS SVIH HRVATSKIH ŽUPANIJA (Aproksimirane granice)
-- Koristimo ST_GeomFromText s POLYGON-ima koji prate oblik HR

-- --- SJEVER I SREDIŠNJA HRVATSKA ---
INSERT INTO regija (naziv, geom) VALUES
('Grad Zagreb', ST_GeomFromText('POLYGON((15.8 45.9, 16.1 45.9, 16.1 45.7, 15.8 45.7, 15.8 45.9))', 4326)),
('Zagrebačka županija', ST_GeomFromText('POLYGON((15.4 46.0, 16.4 46.0, 16.4 45.5, 15.4 45.5, 15.4 46.0))', 4326)),
('Krapinsko-zagorska', ST_GeomFromText('POLYGON((15.6 46.3, 16.2 46.3, 16.2 45.9, 15.6 45.9, 15.6 46.3))', 4326)),
('Varaždinska', ST_GeomFromText('POLYGON((16.0 46.4, 16.7 46.4, 16.7 46.1, 16.0 46.1, 16.0 46.4))', 4326)),
('Međimurska županija', ST_GeomFromText('POLYGON((16.3 46.55, 16.7 46.55, 16.7 46.3, 16.3 46.3, 16.3 46.55))', 4326)),
('Koprivničko-križevačka', ST_GeomFromText('POLYGON((16.4 46.3, 17.2 46.3, 17.2 45.9, 16.4 45.9, 16.4 46.3))', 4326)),
('Bjelovarsko-bilogorska', ST_GeomFromText('POLYGON((16.6 46.0, 17.3 46.0, 17.3 45.5, 16.6 45.5, 16.6 46.0))', 4326)),
('Sisačko-moslavačka', ST_GeomFromText('POLYGON((15.9 45.6, 17.0 45.6, 17.0 45.0, 15.9 45.0, 15.9 45.6))', 4326)),
('Karlovačka županija', ST_GeomFromText('POLYGON((15.2 45.7, 15.8 45.7, 15.8 44.9, 15.2 44.9, 15.2 45.7))', 4326));

-- --- SLAVONIJA ---
INSERT INTO regija (naziv, geom) VALUES
('Virovitičko-podravska', ST_GeomFromText('POLYGON((17.2 46.0, 18.0 46.0, 18.0 45.5, 17.2 45.5, 17.2 46.0))', 4326)),
('Požeško-slavonska', ST_GeomFromText('POLYGON((17.4 45.6, 18.0 45.6, 18.0 45.2, 17.4 45.2, 17.4 45.6))', 4326)),
('Brodsko-posavska', ST_GeomFromText('POLYGON((17.2 45.3, 18.6 45.3, 18.6 45.0, 17.2 45.0, 17.2 45.3))', 4326)),
('Osječko-baranjska', ST_GeomFromText('POLYGON((18.0 45.9, 19.1 45.9, 19.1 45.3, 18.0 45.3, 18.0 45.9))', 4326)),
('Vukovarsko-srijemska', ST_GeomFromText('POLYGON((18.7 45.4, 19.5 45.4, 19.5 44.8, 18.7 44.8, 18.7 45.4))', 4326));

-- --- ISTRA, KVARNER I LIKA ---
INSERT INTO regija (naziv, geom) VALUES
('Istarska županija', ST_GeomFromText('POLYGON((13.5 45.5, 14.2 45.5, 14.2 44.7, 13.9 44.7, 13.5 45.5))', 4326)),
('Primorsko-goranska', ST_GeomFromText('POLYGON((14.2 45.7, 15.2 45.7, 15.2 44.5, 14.2 44.5, 14.2 45.7))', 4326)),
('Ličko-senjska', ST_GeomFromText('POLYGON((14.8 45.1, 15.9 45.1, 15.9 44.3, 14.8 44.3, 14.8 45.1))', 4326));

-- --- DALMACIJA ---
INSERT INTO regija (naziv, geom) VALUES
('Zadarska županija', ST_GeomFromText('POLYGON((14.6 44.6, 16.0 44.6, 16.0 43.9, 14.6 43.9, 14.6 44.6))', 4326)),
('Šibensko-kninska', ST_GeomFromText('POLYGON((15.6 44.2, 16.4 44.2, 16.4 43.5, 15.6 43.5, 15.6 44.2))', 4326)),
('Splitsko-dalmatinska', ST_GeomFromText('POLYGON((16.0 44.0, 17.3 44.0, 17.3 43.0, 16.0 43.0, 16.0 44.0))', 4326)),
('Dubrovačko-neretvanska', ST_GeomFromText('POLYGON((17.3 43.1, 18.6 43.1, 18.6 42.3, 17.3 42.3, 17.3 43.1))', 4326));

-- 4. VRAĆANJE GAŽA (2025)
INSERT INTO gaza (klub_id, kategorija_id, datum_nastupa, honorar, troskovi, opis) VALUES
(1, 1, '2025-05-02', 600.00, 20.00, 'Boogaloo'), (3, 3, '2025-05-03', 350.00, 30.00, 'Samobor'), (4, 1, '2025-05-09', 500.00, 150.00, 'Osijek'), (5, 1, '2025-05-10', 450.00, 20.00, 'Epic'), (2, 1, '2025-05-23', 800.00, 30.00, 'Peti Kupe'), (1, 1, '2025-05-30', 600.00, 20.00, 'ZG Close'),
(6, 1, '2025-06-06', 550.00, 100.00, 'Rijeka'), (7, 2, '2025-06-07', 400.00, 50.00, 'Pula'), (8, 1, '2025-06-14', 900.00, 120.00, 'Rovinj'), (8, 4, '2025-06-15', 1200.00, 0.00, 'Vjenčanje'), (6, 1, '2025-06-20', 600.00, 100.00, 'Rijeka'), (7, 3, '2025-06-21', 300.00, 30.00, 'Pula Beach'),
(14, 1, '2025-07-04', 700.00, 200.00, 'Zadar'), (13, 2, '2025-07-05', 1500.00, 50.00, 'Zrće'), (9, 1, '2025-07-11', 1000.00, 250.00, 'Split'), (10, 3, '2025-07-12', 400.00, 20.00, 'Split Vanilla'), (12, 1, '2025-07-18', 2000.00, 150.00, 'Hvar'), (11, 1, '2025-07-25', 1800.00, 300.00, 'Dubrovnik');