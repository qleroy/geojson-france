-- Corrige et normalise en MULTIPOLYGON (orientation RFC 7946)
UPDATE public.dz
SET geom =
  ST_Multi(
    ST_ForcePolygonCCW(
      ST_CollectionExtract(
        ST_MakeValid(geom),
        3
      )
    )
  )
WHERE geom IS NOT NULL;

