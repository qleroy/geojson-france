DROP TABLE IF EXISTS public.dz_dump;
CREATE TABLE public.dz_dump AS
WITH parts AS (
  SELECT
    dz.id,
    dz.name_dz,
    (d).path  AS part_path,            -- ex: {1}, {2}, ...
    (d).geom  AS geom_2154_part        -- géométrie POLYGON (ou MULTI si mono) en SRID d'origine
  FROM public.dz
  CROSS JOIN LATERAL ST_Dump(dz.geom_2154_simplified) AS d
)
SELECT
  id,
  name_dz,
  part_path[1]::int AS part_index,     -- index de la partie
  geom_2154_part,                      -- la partie (POLYGON)
  (
    jsonb_build_object(
      'type','Feature',
      'geometry', ST_AsGeoJSON(ST_Transform(geom_2154_part, 4326))::jsonb,
      'properties', jsonb_build_object('id', id, 'part', part_path[1])
    )
  )::text AS feature
FROM parts;

