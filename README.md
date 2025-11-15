# 🗺️ GeoJSON France – PostGIS utils
Ce projet contient des données géographiques françaises au format GeoJSON et fournit des snippets SQL pour préparer, nettoyer et optimiser ces données avec PostGIS.
Ces scripts couvrent les besoins courants :
- ✅ Réparer les géométries invalides
- ✅ Simplifier les géométries pour usage web (Leaflet, Mapbox, etc.)
- ✅ Éclater les MULTIPOLYGON en POLYGON
- ✅ Ne garder que le polygone le plus important d’une géométrie

## Créer des géométries custom à partir de ADMIN EXPRESS
```bash
python -m venv venv
source venv/bin/activate
python -m pip install -r requirements.txt
jupyter lab
# Modifier DATA_DIR si besoin
```

## Importer un GeoJSON dans PostgreSQL/PostGIS

### 📦 Prérequis
- GDAL/OGR installé (avec support PostgreSQL/PostGIS)
- Une base PostgreSQL/PostGIS accessible
- Accès en écriture à la base

### ⚙️ Variables d'environnement
```bash
export PGHOST=<votre_hôte>
export PGPORT=<votre_port>
export PGDATABASE=<votre_base>
export PGUSER=<votre_user>
export PGPASSWORD=<votre_mot_de_passe>

export GEOJSON=<chemin_vers_votre_geojson>
export TABLE=<nom_de_votre_schema.nom_de_votre_table>
```

Exemple :
```bash
export PGHOST=127.0.0.1
export PGPORT=5432
export PGDATABASE=postgres
export PGUSER=postgres
export PGPASSWORD=mot_de_passe_compliqué

export GEOJSON=data/dz.geojson
export TABLE=public.dz
```

```bash
ogr2ogr \
  --config OGR_GEOJSON_MAX_OBJ_SIZE 0 \
  --config PG_USE_COPY YES \
  -f PostgreSQL \
  PG:"host=$PGHOST dbname=$PGDATABASE user=$PGUSER password=$PGPASSWORD port=$PGPORT" \
  $GEOJSON \
  -nln $TABLE \
  -lco GEOMETRY_NAME=geom \
  -lco FID=id \
  -nlt PROMOTE_TO_MULTI \
  -t_srs EPSG:4326 \
  -skipfailures
```

### 📖 Options utilisées
- `--config OGR_GEOJSON_MAX_OBJ_SIZE 0` : pas de limite sur la taille des entités GeoJSON
- `--config PG_USE_COPY YES` : import rapide avec COPY
- `-nln public.out2` : nom de la table créée = public.out2
- `-lco GEOMETRY_NAME=geom` : colonne géométrique = geom
- `-lco FID=id` : clé primaire = id
- `-nlt PROMOTE_TO_MULTI` : force les géométries en Multi (MultiPolygon, etc.)
- `-t_srs EPSG:4326` : reprojection en WGS84
- `-skipfailures` : ignore les entités invalides


## Préparer

### 1. Réparer et normaliser les géométries
Certaines géométries peuvent être invalides (self-intersections, bow-ties, trous à l’extérieur…).

[01_fix_geometries.sql](./sql/01_fix_geometries.sql)

### 2. Simplifier les géométries
Les géométries fines peuvent être lourdes pour l’affichage web.
On simplifie donc en **Lambert-93 (2154, mètres)** puis on reprojette en WGS84 (4326).

[02_build_geom_simplified.sql](./sql/02_build_geom_simplified.sql)

### 3a. Éclater les MultiPolygons
Un `MULTIPOLYGON` peut contenir plusieurs polygones distincts.
On peut les éclater pour obtenir `un polygone par ligne` :

[04_dump_polygons.sql](./sql/04_dump_polygons.sql)

### 3b. Garder uniquement le polygone principal
Pour éviter les petits morceaux isolés (ex: îles, artefacts),
on peut ne garder **que le plus grand polygone** de chaque entité.

[05_largest_polygon.sql](./sql/05_largest_polygon.sql)

### 🚀 Usage typique
- **Nettoyage initial** → `UPDATE ... ST_MakeValid`
- **Simplification** → `ST_SimplifyPreserveTopology` avec tolérance
- **Éclatement** → `ST_Dump`
- **Polygone principal** → `ROW_NUMBER() OVER ... ORDER BY ST_Area DESC`

👉 Ces snippets permettent de préparer des données propres, légères et prêtes pour le web.
