CREATE OR REPLACE VIEW public.dz_largest_poly AS
WITH dumped AS (
  SELECT dz.id, dz.name_dz, (d).geom AS part_geom
  FROM public.dz
  CROSS JOIN LATERAL ST_Dump(dz.geom) AS d
),
ranked AS (
  SELECT
    id, name_dz, part_geom,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY ST_Area(part_geom) DESC) AS rn
  FROM dumped
)
SELECT
  id, 
  name_dz,
  json_build_object(
    'type','Feature',
    'geometry', ST_AsGeoJSON(part_geom)::jsonb,
    'properties', json_build_object()
  )::text AS feature
FROM ranked
WHERE rn = 1;
