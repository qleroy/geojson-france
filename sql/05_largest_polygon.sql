/*
 ================================================================================
 Pour chaque MULTIPOLYGON, extraire le POLYGON de plus grande surface.
 
 LOGIQUE :
 1) ST_Dump pour obtenir 1 POLYGON par ligne
 2) Classer par aire (calculée en 2154, unités en m²)
 3) Garder la plus grande partie (rn = 1)
 
 RÉSULTAT :
 - Création d'une nouvelle table `public.zone_largest_poly`
 - Colonnes :
 geom_4326 : POLYGON en EPSG:4326
 geojson    : géométrie en JSONB (6 décimales)
 feature    : Feature (text)
 ================================================================================
 */
-- Supprime la table si elle existe déjà, pour éviter les erreurs à la création
DROP TABLE IF EXISTS public.zone_largest_poly;
-- Création d'une nouvelle table résultante
-- 1) Préparer les géométries (validité + extraction POLYGON)
CREATE TABLE public.zone_largest_poly AS WITH dumped AS (
  SELECT z.id,
    z.nom_zone,
    (part).geom -- POLYGON
  FROM public.zone z
    CROSS JOIN LATERAL ST_Dump(z.geom) AS part
    -- CROSS JOIN LATERAL ST_Dump(z.geom_simplified) AS part
),
ranked AS (
  SELECT id,
    nom_zone,
    geom,
    ROW_NUMBER() OVER (
      PARTITION BY id
      ORDER BY -- Aire en Lambert-93 (m²) pour un tri fiable
        ST_Area(ST_Transform(geom, 2154)) DESC,
        -- Tie-breaker stable : périmètre puis WKT
        ST_Perimeter(ST_Transform(geom, 2154)) DESC,
        ST_AsText(geom) ASC
    ) AS rn
  FROM dumped
),
final AS (
  SELECT id,
    nom_zone,
    ST_Transform(geom, 4326) AS geom
  FROM ranked
  WHERE rn = 1
)
SELECT id,
  nom_zone,
  geom,
  jsonb_build_object(
    'type',
    'Feature',
    'geometry',
    ST_AsGeoJSON(geom_4326, 6)::jsonb,
    'properties',
    jsonb_build_object()
  )::text AS feature
FROM final;