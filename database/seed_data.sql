
-- Seed podataka

INSERT INTO kategorija (naziv, boja) VALUES 
    ('Klub', '#e74c3c'), 
    ('Festival', '#9b59b6'), 
    ('Bar', '#3498db'), 
    ('Privatni event', '#f1c40f');

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

INSERT INTO gaza (klub_id, kategorija_id, datum_nastupa, honorar, troskovi, opis) VALUES
    (1, 1, '2025-05-02', 600.00, 20.00, 'Boogaloo'), 
    (3, 3, '2025-05-03', 350.00, 30.00, 'Samobor'), 
    (4, 1, '2025-05-09', 500.00, 150.00, 'Osijek'), 
    (5, 1, '2025-05-10', 450.00, 20.00, 'Epic'), 
    (2, 1, '2025-05-23', 800.00, 30.00, 'Peti Kupe'), 
    (1, 1, '2025-05-30', 600.00, 20.00, 'ZG Close'),
    (6, 1, '2025-06-06', 550.00, 100.00, 'Rijeka'), 
    (7, 2, '2025-06-07', 400.00, 50.00, 'Pula'), 
    (8, 1, '2025-06-14', 900.00, 120.00, 'Rovinj'), 
    (8, 4, '2025-06-15', 1200.00, 0.00, 'Vjenčanje'), 
    (6, 1, '2025-06-20', 600.00, 100.00, 'Rijeka'), 
    (7, 3, '2025-06-21', 300.00, 30.00, 'Pula Beach'),
    (14, 1, '2025-07-04', 700.00, 200.00, 'Zadar'), 
    (13, 2, '2025-07-05', 1500.00, 50.00, 'Zrće'), 
    (9, 1, '2025-07-11', 1000.00, 250.00, 'Split'), 
    (10, 3, '2025-07-12', 400.00, 20.00, 'Split Vanilla'), 
    (12, 1, '2025-07-18', 2000.00, 150.00, 'Hvar'), 
    (11, 1, '2025-07-25', 1800.00, 300.00, 'Dubrovnik');