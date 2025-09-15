# 🗺️ GeoJSON France – PostGIS utils
Ce projet contient des données géographiques françaises au format GeoJSON et fournit des snippets SQL pour préparer, nettoyer et optimiser ces données avec PostGIS.
Ces scripts couvrent les besoins courants :
- ✅ Réparer les géométries invalides
- ✅ Ajouter une colonne geojson prête à l’emploi
- ✅ Simplifier les géométries pour usage web (Leaflet, Mapbox, etc.)
- ✅ Éclater les MULTIPOLYGON en POLYGON
- ✅ Ne garder que le polygone le plus important d’une géométrie

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
Le snippet ci-dessous corrige les géométries et garantit un type MULTIPOLYGON.

```sql
-- Nettoyage des géométries invalides
UPDATE public.dz
SET geom_2154 =
  ST_Multi(                       -- ✅ force le type final en MULTIPOLYGON
    ST_ForcePolygonCCW(           -- ✅ oriente les polygones selon RFC 7946 (outer CCW, holes CW)
      ST_CollectionExtract(       -- ✅ garde uniquement les POLYGONES (code 3)
        ST_MakeValid(geom),       -- ✅ répare la géométrie (auto-intersections, etc.)
        3
      )
    )
  )
WHERE geom IS NOT NULL;
```

### 2. Ajouter une colonne GeoJSON
Pour exposer directement les données au format GeoJSON, on peut ajouter une colonne `geojson` :
```sql
-- Ajouter une colonne GeoJSON (si non existante)
ALTER TABLE public.departements_10 
ADD COLUMN geojson text;

-- Remplir la colonne avec un Feature minimal
UPDATE public.departements_10
SET geojson = 
  json_build_object(
    'type','Feature',
    'geometry', ST_AsGeoJSON(ST_Transform(geom, 4326))::json,
    'properties', json_build_object()
  )::text
WHERE geom IS NOT NULL;
```

### 3. Simplifier les géométries
Les géométries fines peuvent être lourdes pour l’affichage web.
On simplifie donc en **Lambert-93 (2154, mètres)** puis on reprojette en WGS84 (4326).
```sql
-- 1) Ajouter une colonne en Lambert-93
ALTER TABLE public.dz
ADD COLUMN IF NOT EXISTS geom_2154 geometry(MultiPolygon, 2154);

-- 2) Remplir avec la reprojection
UPDATE public.dz
SET geom_2154 = ST_Transform(geom, 2154)
WHERE geom IS NOT NULL;

-- 3) Simplifier (tolérance = 500 m par défaut)
UPDATE public.dz d
SET geom_2154 = ST_SimplifyPreserveTopology(d.geom_2154, 500::double precision)
WHERE d.geom_2154 IS NOT NULL;

-- 4) Créer une vue exploitable directement en WGS84 + GeoJSON
DROP VIEW IF EXISTS dz_wgs84;
CREATE OR REPLACE VIEW public.dz_wgs84 AS
SELECT
  id,
  name_dz,
  ST_Transform(geom_2154, 4326) AS geom,
  ST_AsGeoJSON(ST_Transform(geom_2154, 4326))::jsonb AS geojson,
  json_build_object(
    'type', 'Feature',
    'geometry', ST_AsGeoJSON(ST_Transform(geom_2154, 4326))::jsonb,
    'properties', json_build_object()
  )::text AS feature
FROM public.dz
WHERE geom_2154 IS NOT NULL;
```

### 4. . Éclater les MultiPolygons
Un `MULTIPOLYGON` peut contenir plusieurs polygones distincts.
On peut les éclater pour obtenir `un polygone par ligne` :
```sql
CREATE TABLE public.dz_dump AS
SELECT
  json_build_object(
    'type', 'Feature',
    'geometry',
      ST_AsGeoJSON(
        ST_Transform(
          ST_SimplifyPreserveTopology(
            ST_Transform(d.geom, 2154),     -- simplification en Lambert-93
            500::double precision           -- tolérance (mètres)
          ),
          4326                             -- retour en WGS84
        )
      )::jsonb,
    'properties', json_build_object()
  )::text AS geom
FROM public.dz
CROSS JOIN LATERAL ST_Dump(z.geom) AS d;   -- éclate MultiPolygon → Polygons
```

### 5. Garder uniquement le polygone principal
Pour éviter les petits morceaux isolés (ex: îles, artefacts),
on peut ne garder **que le plus grand polygone** de chaque entité.
```sql
CREATE OR REPLACE VIEW public.dz_largest_poly_wgs84 AS

-- Étape 1 : éclater les MultiPolygons
WITH dumped AS (
  SELECT
    dz.id,
    dz.name_dz,
    (d).geom AS part_geom_2154
  FROM public.dz
  CROSS JOIN LATERAL ST_Dump(z.geom_2154) AS d
),

-- Étape 2 : calculer la surface et classer
ranked AS (
  SELECT
    id,
    name_dz,
    part_geom_2154,
    ROW_NUMBER() OVER (
      PARTITION BY id
      ORDER BY ST_Area(part_geom_2154) DESC
    ) AS rn
  FROM dumped
)

-- Étape 3 : garder seulement le plus grand (rn = 1)
SELECT
  id,
  name_dz,
  ST_Transform(part_geom_2154, 4326)::text AS geom,
  json_build_object(
    'type', 'Feature',
    'geometry',
      ST_AsGeoJSON(
        ST_Transform(
          ST_SimplifyPreserveTopology(
            ST_Transform(part_geom_2154, 2154),
            500::double precision
          ),
          4326
        )
      )::jsonb,
    'properties', json_build_object()
  )::text AS feature
FROM ranked
WHERE rn = 1;
```

### 🚀 Usage typique
- **Nettoyage initial** → `UPDATE ... ST_MakeValid`
- **Ajout GeoJSON** → `ALTER TABLE ... ADD COLUMN geojson`
- **Simplification** → `ST_SimplifyPreserveTopology` avec tolérance
- **Éclatement** → `ST_Dump`
- **Polygone principal** → `ROW_NUMBER() OVER ... ORDER BY ST_Area DESC`

👉 Ces snippets permettent de préparer des données propres, légères et prêtes pour le web.
