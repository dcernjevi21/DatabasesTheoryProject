from flask import Flask, jsonify, request, render_template
from sqlalchemy import text
from flask_sqlalchemy import SQLAlchemy
import json

app = Flask(__name__)
# !!!!!!!!! LOZINKA ZA BAZU !!!!!!!!!!!!!!!!!!!
app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres:postgres@localhost/geotracker' # Promijeniti prema potrebi postgresql://postgres:______@localhost/geotracker
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

@app.route('/')
def index():
    return render_template('index.html')

# Ruta za dohvat klubova
@app.route('/api/clubs')
def get_clubs():
    sql = text("SELECT id, naziv, adresa, ST_AsGeoJSON(geom) as geom FROM klub")
    res = db.session.execute(sql)
    return jsonify({"type":"FeatureCollection", "features":[{"type":"Feature","geometry":json.loads(r.geom),"properties":{"id":r.id,"naziv":r.naziv,"adresa":r.adresa}} for r in res]})

# Ruta za dohvat rute za odabrani mjesec
@app.route('/api/route')
def get_route():
    month = request.args.get('month')
    res = db.session.execute(text("SELECT get_monthly_route(:m) as geom"), {'m': month}).fetchone()
    return jsonify({"type": "Feature", "geometry": res.geom} if res and res.geom else {})

@app.route('/api/months')
def get_months():
    res = db.session.execute(text("SELECT * FROM view_dostupni_mjeseci"))
    return jsonify([{"id":r.id, "naziv":r.naziv} for r in res])


# Ruta za dohvat regija
@app.route('/api/regions')
def get_regions():
    try:
        sql = text("SELECT naziv, ST_AsGeoJSON(geom) as geom FROM regija")
        result = db.session.execute(sql)
        
        features = []
        for row in result:
            geometry = json.loads(row.geom)
            
            features.append({
                "type": "Feature",
                "geometry": geometry,
                "properties": { 
                    "naziv": row.naziv 
                }
            })
            
        return jsonify({
            "type": "FeatureCollection", 
            "features": features
        })
    except Exception as e:
        print(f"Greška u get_regions: {e}")
        return jsonify({"error": str(e)}), 500

# Ruta za dohvat statistike
@app.route('/api/stats')
def get_stats():
    month = request.args.get('month')
    row = db.session.execute(text("SELECT * FROM view_statistika_mjesec WHERE id_mjeseca = :m"), {'m': month}).fetchone()
    km = db.session.execute(text("SELECT ukupni_km_mjeseca(:m)"), {'m': month}).scalar() or 0
    
    if row:
        return jsonify({"broj": row.broj_gaza, "profit": float(row.profit), "km": round(km, 1)})
    return jsonify({"broj": 0, "profit": 0, "km": 0})

# Ruta za dohvat gaža
@app.route('/api/gigs')
def get_gigs():
    month = request.args.get('month')
    sql = text("""
        SELECT g.id, k.naziv, g.datum_nastupa, g.honorar, g.troskovi, cat.boja, ST_AsGeoJSON(k.geom) as geom, g.zakljucano
        FROM gaza g
        JOIN klub k ON g.klub_id = k.id
        JOIN kategorija cat ON g.kategorija_id = cat.id
        WHERE to_char(g.datum_nastupa, 'YYYY-MM') = :m
        ORDER BY g.datum_nastupa
    """)
    result = db.session.execute(sql, {'m': month})
    features = []
    for r in result:
        features.append({
            "type": "Feature", "geometry": json.loads(r.geom),
            "properties": {
                "id": r.id, "naziv": r.naziv, "datum": str(r.datum_nastupa), 
                "honorar": float(r.honorar), "troskovi": float(r.troskovi),
                "boja": r.boja, "locked": r.zakljucano
            }
        })
    return jsonify({"type": "FeatureCollection", "features": features})

# Uredi Gažu
@app.route('/api/gigs/<int:id>', methods=['PUT'])
def update_gig(id):
    d = request.json
    try:
        sql = text("UPDATE gaza SET honorar=:h, troskovi=:t WHERE id=:id")
        db.session.execute(sql, {'h': d['honorar'], 't': d['trosak'], 'id': id})
        db.session.commit()
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"error": str(e)}), 400

# Ruta za dohvat top liste
@app.route('/api/top')
def get_top():
    res = db.session.execute(text("SELECT * FROM view_top_klubovi LIMIT 5"))
    return jsonify([{"naziv": r.naziv, "regija": r.regija, "nastupa": r.broj_nastupa, "profit": float(r.ukupni_profit)} for r in res])

# Ruta za zaaključavanje mjeseca
@app.route('/api/lock', methods=['POST'])
def lock_month():
    month = request.json.get('month')
    try:
        # Poziv procedure s COMMIT unutar nje
        # Flask-SQLAlchemy automatski radi u transakciji, pa moramo koristiti raw connection za poziv (call)
        with db.engine.connect() as conn:
            conn.execute(text(f"CALL zakljucaj_mjesec('{month}')"))
            conn.commit()
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"error": str(e)}), 400

# Ruta za dodavanje novog kluba i gaže
@app.route('/api/add', methods=['POST'])
def add_data():
    d = request.json
    try:
        klub_id = d.get('klub_id')
        if not klub_id:
            sql_klub = text("INSERT INTO klub (naziv, adresa, geom) VALUES (:n, :a, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)) RETURNING id")
            klub_id = db.session.execute(sql_klub, {'n': d['naziv'], 'a': d['adresa'], 'lon': d['lon'], 'lat': d['lat']}).scalar()
        
        sql_gaza = text("INSERT INTO gaza (klub_id, datum_nastupa, honorar, troskovi, kategorija_id) VALUES (:kid, :d, :h, :t, :c)")
        db.session.execute(sql_gaza, {'kid': klub_id, 'd': d['datum'], 'h': d['honorar'], 't': d['trosak'], 'c': int(d['kat'])})
        db.session.commit()
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"error": str(e)}), 400

if __name__ == '__main__':
    app.run(debug=True)