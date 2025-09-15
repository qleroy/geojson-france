ALTER TABLE public.dz
ADD COLUMN IF NOT EXISTS geom_2154 geometry(MultiPolygon, 2154);

UPDATE public.dz
SET geom_2154 = ST_Transform(geom, 2154)
WHERE geom IS NOT NULL;

UPDATE public.dz
SET geom_2154 = ST_SimplifyPreserveTopology(dz.geom_2154, 500::double precision)
WHERE dz.geom_2154 IS NOT NULL;

DROP VIEW IF EXISTS public.dz_simplified;
CREATE OR REPLACE VIEW public.dz_simplified AS
SELECT
  id,
  name_dz,
  ST_Transform(geom_2154, 4326) AS geom,
  ST_AsGeoJSON(ST_Transform(geom_2154, 4326))::jsonb AS geojson,
  json_build_object(
    'type','Feature',
    'geometry', ST_AsGeoJSON(ST_Transform(geom_2154, 4326))::jsonb,
    'properties', json_build_object()
  )::text AS feature
FROM public.dz
WHERE geom_2154 IS NOT NULL;
