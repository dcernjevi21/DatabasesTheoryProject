import json
from sqlalchemy import create_engine, text

# --- KONFIGURACIJA ---
# Promijeni lozinku ako treba
DB_URI = 'postgresql://postgres:postgres@localhost/geotracker'
LOKALNA_DATOTEKA = 'hr-counties.json'

def import_zupanije_lokalno():
    print("1. Spajam se na bazu...")
    try:
        engine = create_engine(DB_URI)
        conn = engine.connect().execution_options(isolation_level="AUTOCOMMIT")
    except Exception as e:
        print(f"GREŠKA pri spajanju: {e}")
        return

    print(f"2. Učitavam lokalnu datoteku '{LOKALNA_DATOTEKA}'...")
    try:
        with open(LOKALNA_DATOTEKA, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"GREŠKA: Datoteka '{LOKALNA_DATOTEKA}' nije pronađena!")
        return
    except Exception as e:
        print(f"GREŠKA pri čitanju datoteke: {e}")
        return

    print("3. Brišem stare regije...")
    try:
        conn.execute(text("TRUNCATE TABLE regija CASCADE"))
    except Exception as e:
        print(f"Upozorenje: {e}")

    print("4. Uvozim podatke u bazu...")
    count = 0
    errors = 0
    
    # SQL koji pretvara JSON geometriju u PostGIS format
    # ST_Multi: pretvara Polygon u MultiPolygon (jer je tablica takva)
    # ST_MakeValid: popravlja geometrijske greške (ako se linije križaju)
    # ST_Force2D: miče visinu (Z koordinatu) ako postoji
    insert_sql = text("""
        INSERT INTO regija (naziv, geom) 
        VALUES (:ime, ST_Multi(ST_MakeValid(ST_Force2D(ST_SetSRID(ST_GeomFromGeoJSON(:geom), 4326)))))
    """)

    features = data.get('features', [])
    if not features:
        if isinstance(data, list):
            features = data
        else:
            print("GREŠKA: Nepoznat format GeoJSON-a (nema 'features' liste).")
            return

    for feature in features:
        props = feature.get('properties', {})
        
        naziv = (props.get('name') or props.get('NAME') or 
                 props.get('gn_name') or props.get('zupanija'))
        
        if not naziv:
            naziv = f"Regija {props.get('id', 'Nepoznata')}"
            
        naziv = naziv.strip()
        
        geometrija_json = json.dumps(feature['geometry'])

        try:
            conn.execute(insert_sql, {'ime': naziv, 'geom': geometrija_json})
            count += 1
            print(f"   [OK] Uvezena: {naziv}")
        except Exception as e:
            errors += 1
            print(f"   [GREŠKA] {naziv}: {e}")

    print(f"\n=== GOTOVO! Uspješno: {count}, Greške: {errors} ===")
    conn.close()

if __name__ == "__main__":
    import_zupanije_lokalno()