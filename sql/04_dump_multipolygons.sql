CREATE TABLE IF NOT EXISTS public.dz_dump AS
SELECT
  json_build_object(
    'type','Feature',
    'geometry', ST_AsGeoJSON(d.geom)::jsonb,
    'properties', json_build_object()
  )::text AS feature
FROM public.dz
CROSS JOIN LATERAL ST_Dump(dz.geom) AS d;

