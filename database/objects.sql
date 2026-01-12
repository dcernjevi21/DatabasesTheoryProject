-- pogled

CREATE OR REPLACE VIEW pogled_statistika_kategorija AS
SELECT 
    k.naziv AS kategorija,
    COUNT(l.id) AS broj_lokacija,
    COALESCE(ROUND(AVG(l.ocjena), 2), 0) AS prosjecna_ocjena
FROM 
    kategorija k
LEFT JOIN 
    lokacija l ON k.id = l.kategorija_id
GROUP BY 
    k.id, k.naziv
ORDER BY 
    broj_lokacija DESC;

-- test SELECT * FROM pogled_statistika_kategorija;

-- PROSTORNA FUNKCIJA: "Što je blizu mene?" (Najvažniji dio!)

CREATE OR REPLACE FUNCTION pronadi_u_blizini(
    moj_lon FLOAT,      -- Longitude (X)
    moj_lat FLOAT,      -- Latitude (Y)
    radijus_km FLOAT    -- Radijus u kilometrima
)
RETURNS TABLE (
    naziv VARCHAR,
    opis TEXT,
    kategorija VARCHAR,
    udaljenost_m FLOAT,  -- Udaljenost u metrima
    geo_lat FLOAT,
    geo_lon FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.naziv,
        l.opis,
        k.naziv AS kategorija,
        -- Izračunaj udaljenost na sferi (zato cast u geography)
        ST_Distance(
            l.geom::geography, 
            ST_SetSRID(ST_MakePoint(moj_lon, moj_lat), 4326)::geography
        ) AS udaljenost_m,
        ST_Y(l.geom) as geo_lat, -- Izvuci Y za frontend
        ST_X(l.geom) as geo_lon  -- Izvuci X za frontend
    FROM 
        lokacija l
    JOIN 
        kategorija k ON l.kategorija_id = k.id
    WHERE 
        -- Filter: koristi indeks (vrlo brzo)
        ST_DWithin(
            l.geom::geography,
            ST_SetSRID(ST_MakePoint(moj_lon, moj_lat), 4326)::geography,
            radijus_km * 1000 -- Pretvori km u metre
        )
    ORDER BY 
        udaljenost_m ASC;
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM pronadi_u_blizini(15.97, 45.81, 5.0); (traži sve u 5km radijusu u centru ZG)

--  TRIGGER (OKIDAČ): Automatsko ažuriranje vremena

-- 1. Dodaj stupac u tablicu lokacija
ALTER TABLE lokacija ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- 2. Kreiraj funkciju koju će trigger zvati
CREATE OR REPLACE FUNCTION azuriraj_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Poveži trigger s tablicom
CREATE TRIGGER trg_update_lokacija
BEFORE UPDATE ON lokacija
FOR EACH ROW
EXECUTE FUNCTION azuriraj_timestamp();

-- SADA, KAD GOD SE LOKACIJA AŽURIRA, STUPAC updated_at ĆE AUTOMATSKI DOBITI TRENUTNO VRIJEME

-- PROCEDURA: Generiranje testnih podataka (Sjajno za demonstraciju)

CREATE OR REPLACE PROCEDURE generiraj_testne_podatke(
    centar_lon FLOAT, 
    centar_lat FLOAT, 
    broj_tocaka INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
    rnd_lat FLOAT;
    rnd_lon FLOAT;
    kat_id INT;
BEGIN
    FOR i IN 1..broj_tocaka LOOP
        -- Generiraj random pomak (cca +/- 0.1 stupanj, što je oko 10km)
        rnd_lon := centar_lon + (random() * 0.2 - 0.1);
        rnd_lat := centar_lat + (random() * 0.2 - 0.1);
        
        -- Odaberi random kategoriju (1 do 4)
        kat_id := floor(random() * 4 + 1)::INT;
        
        INSERT INTO lokacija (naziv, opis, kategorija_id, geom, ocjena)
        VALUES (
            'Test Lokacija ' || i,
            'Automatski generirana točka za testiranje mape.',
            kat_id,
            ST_SetSRID(ST_MakePoint(rnd_lon, rnd_lat), 4326),
            floor(random() * 5 + 1)::INT
        );
    END LOOP;
END;


CALL generiraj_testne_podatke(15.97, 45.81, 20);
SELECT * FROM pronadi_u_blizini(15.97, 45.81, 10);

