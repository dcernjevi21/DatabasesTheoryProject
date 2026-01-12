from flask import Flask, jsonify, request, render_template
from sqlalchemy import text
from flask_sqlalchemy import SQLAlchemy
import json

app = Flask(__name__)
# PAZI NA LOZINKU
app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://postgres:postgres@localhost/geotracker'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

@app.route('/')
def index():
    return render_template('index.html')

# 1. API: Svi Klubovi (Za "View Unos")
@app.route('/api/clubs')
def get_clubs():
    sql = text("SELECT id, naziv, adresa, ST_AsGeoJSON(geom) as geom FROM klub")
    result = db.session.execute(sql)
    features = []
    for r in result:
        features.append({
            "type": "Feature",
            "geometry": json.loads(r.geom),
            "properties": { "id": r.id, "naziv": r.naziv, "adresa": r.adresa }
        })
    return jsonify({"type": "FeatureCollection", "features": features})

# 2. API: Gaže za određeni mjesec (Za "View Turneja")
@app.route('/api/gigs')
def get_gigs():
    month = request.args.get('month')
    if not month: return jsonify({})
    
    sql = text("""
        SELECT k.naziv, k.adresa, g.datum_nastupa, g.honorar, g.troskovi, 
               cat.boja, ST_AsGeoJSON(k.geom) as geom
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
            "type": "Feature",
            "geometry": json.loads(r.geom),
            "properties": {
                "naziv": r.naziv, "datum": str(r.datum_nastupa), 
                "honorar": float(r.honorar), "boja": r.boja
            }
        })
    return jsonify({"type": "FeatureCollection", "features": features})

# 3. API: Ruta
@app.route('/api/route')
def get_route():
    month = request.args.get('month')
    sql = text("SELECT get_monthly_route(:m) as geom")
    res = db.session.execute(sql, {'m': month}).fetchone()
    if res and res.geom:
        return jsonify({"type": "Feature", "geometry": res.geom})
    return jsonify({})

# 4. API: Statistika
@app.route('/api/stats')
def get_stats():
    month = request.args.get('month')
    sql = text("SELECT * FROM view_statistika_mjesec WHERE id_mjeseca = :m")
    row = db.session.execute(sql, {'m': month}).fetchone()
    if row:
        return jsonify({"broj": row.broj_gaza, "profit": float(row.profit)})
    return jsonify({"broj": 0, "profit": 0})

# 5. API: Mjeseci
@app.route('/api/months')
def get_months():
    sql = text("SELECT * FROM view_dostupni_mjeseci")
    res = db.session.execute(sql)
    return jsonify([{"id": r.id_mjeseca, "naziv": r.naziv_mjeseca} for r in res])

# 6. API: Dodaj Novi Klub ILI Novu Gažu
@app.route('/api/add', methods=['POST'])
def add_data():
    d = request.json
    try:
        # 1. Ako klub ne postoji (nema ID), kreiraj ga
        klub_id = d.get('klub_id')
        if not klub_id:
            sql_klub = text("INSERT INTO klub (naziv, adresa, geom) VALUES (:n, :a, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)) RETURNING id")
            klub_id = db.session.execute(sql_klub, {'n': d['naziv'], 'a': d['adresa'], 'lon': d['lon'], 'lat': d['lat']}).scalar()
        
        # 2. Kreiraj gažu vezanu za taj klub
        sql_gaza = text("INSERT INTO gaza (klub_id, datum_nastupa, honorar, troskovi, kategorija_id) VALUES (:kid, :d, :h, :t, :c)")
        db.session.execute(sql_gaza, {
            'kid': klub_id, 'd': d['datum'], 'h': d['honorar'], 't': d['trosak'], 'c': int(d['kat'])
        })
        db.session.commit()
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"error": str(e)}), 400

# 7. API: Dohvati SVE Regije (Županije)
@app.route('/api/regions')
def get_regions():
    sql = text("SELECT naziv, ST_AsGeoJSON(geom) as geom FROM regija")
    result = db.session.execute(sql)
    
    features = []
    for row in result:
        features.append({
            "type": "Feature",
            "geometry": json.loads(row.geom),
            "properties": { "naziv": row.naziv }
        })
    return jsonify({"type": "FeatureCollection", "features": features})

if __name__ == '__main__':
    app.run(debug=True)