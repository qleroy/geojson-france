/*
================================================================================
Créer une colonne GeoJSON "feature" par ligne à partir de la géométrie
simplifiée (geom_simplified, supposée en EPSG:4326).

RÉSULTAT :
 - Une nouvelle colonne `feature` : GeoJSON de type json
================================================================================
*/
-- 1) Créer la colonne `feature` de type json
ALTER TABLE public.zone
  ADD COLUMN IF NOT EXISTS feature json;
UPDATE public.zone
SET feature = jsonb_build_object(
    'type', 'Feature',
    'geometry', ST_AsGeoJSON(geom_simplified, 6)::jsonb,
    'properties', jsonb_build_object() 
)::text
WHERE geom_simplified IS NOT NULL
  AND NOT ST_IsEmpty(geom_simplified);