from flask_sqlalchemy import SQLAlchemy
from geoalchemy2 import Geometry

# Inicijalizacija objekta baze
db = SQLAlchemy()

# Model za tablicu kategorija
class Kategorija(db.Model):
    __tablename__ = 'kategorija'
    id = db.Column(db.Integer, primary_key=True)
    naziv = db.Column(db.String(50), nullable=False)
    opis = db.Column(db.Text)
    ikona_url = db.Column(db.String(255))

# Model za tablicu lokacija
class Lokacija(db.Model):
    __tablename__ = 'lokacija'
    id = db.Column(db.Integer, primary_key=True)
    naziv = db.Column(db.String(100), nullable=False)
    opis = db.Column(db.Text)
    datum_posjeta = db.Column(db.Date)
    ocjena = db.Column(db.Integer)
    kategorija_id = db.Column(db.Integer, db.ForeignKey('kategorija.id'))
    
    # Definiranje da je geometrijski stupac 
    geom = db.Column(Geometry('POINT', srid=4326))