from flask import Flask, jsonify, request, render_template
from sqlalchemy import text
from models import db, Lokacija, Kategorija
from geoalchemy2.shape import to_shape
import json

app = Flask(__name__)

# --- KONFIGURACIJA ---
# ZAMIJENI 'tvoja_lozinka' SVOJOM STVARNOM LOZINKOM KOJU KORISTIŠ U PGADMINU!
# Format: postgresql://username:password@localhost/ime_baze
app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres:postgres@localhost/geotracker'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Povezivanje s bazom
db.init_app(app)

# --- RUTE (API) ---

@app.route('/')
def index():
    # Ovo traži datoteku 'index.html' u mapi 'templates'
    return render_template('index.html')

# 1. API: Dohvati sve lokacije u GeoJSON formatu (Standard za web mape)
@app.route('/api/locations', methods=['GET'])
def get_locations():
    # Koristimo PostGIS funkciju ST_AsGeoJSON direktno u upitu
    sql = text("""
        SELECT 
            l.id, l.naziv, l.opis, k.naziv as kategorija, 
            ST_AsGeoJSON(l.geom) as geometrija
        FROM lokacija l
        LEFT JOIN kategorija k ON l.kategorija_id = k.id
    """)
    result = db.session.execute(sql)
    
    features = []
    for row in result:
        # Parsiranje JSON-a koji baza vrati
        geometry = json.loads(row.geometrija)
        
        feature = {
            "type": "Feature",
            "geometry": geometry,
            "properties": {
                "id": row.id,
                "naziv": row.naziv,
                "opis": row.opis,
                "kategorija": row.kategorija
            }
        }
        features.append(feature)
    
    return jsonify({
        "type": "FeatureCollection",
        "features": features
    })

# 2. API: Dohvati statistiku (poziva tvoj SQL POGLED)
@app.route('/api/stats', methods=['GET'])
def get_stats():
    # Pozivanje pogleda kojeg smo kreirali u Fazi 2
    sql = text("SELECT * FROM pogled_statistika_kategorija")
    result = db.session.execute(sql)
    
    data = []
    for row in result:
        data.append({
            "kategorija": row.kategorija,
            "broj": row.broj_lokacija,
            "prosjek": float(row.prosjecna_ocjena)
        })
    return jsonify(data)

# 3. API: Unesi novu lokaciju (poziva se kad klikneš na mapu)
@app.route('/api/add', methods=['POST'])
def add_location():
    data = request.json
    try:
        # SQL upit za unos s pretvorbom koordinata u geometriju
        sql = text("""
            INSERT INTO lokacija (naziv, opis, kategorija_id, ocjena, geom)
            VALUES (:naziv, :opis, :kat_id, :ocjena, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326))
        """)
        
        db.session.execute(sql, {
            'naziv': data['naziv'],
            'opis': data.get('opis', ''),
            'kat_id': int(data['kategorija_id']),
            'ocjena': int(data['ocjena']),
            'lon': float(data['lon']),
            'lat': float(data['lat'])
        })
        db.session.commit()
        return jsonify({"message": "Spremljeno!"}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 400

if __name__ == '__main__':
    app.run(debug=True)