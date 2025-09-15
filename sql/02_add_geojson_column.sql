ALTER TABLE public.dz
ADD COLUMN IF NOT EXISTS geojson text;

UPDATE public.dz
SET geojson = json_build_object(
  'type','Feature',
  'geometry', ST_AsGeoJSON(ST_Transform(geom, 4326))::json,
  'properties', json_build_object()
)::text
WHERE geom IS NOT NULL;

