/*
 ================================================================================
 Normaliser la géométrie en MULTIPOLYGON (orientation RFC 7946)
 dans une nouvelle colonne : geom_norm
 ================================================================================
 */
-- 1) Ajouter la colonne cible si absente (SRID libre, on l'assigne à l'UPDATE)
ALTER TABLE public.zone
ADD COLUMN IF NOT EXISTS geom_norm geometry(MULTIPOLYGON);
-- 2) Écrire la géométrie normalisée dans geom_norm
UPDATE public.zone
SET geom_norm = ST_SetSRID(
    ST_Multi(
      ST_ForcePolygonCCW(
        ST_CollectionExtract(
          ST_MakeValid(geom),
          3 -- POLYGON
        )
      )
    ),
    COALESCE(NULLIF(ST_SRID(geom), 0), 2154) -- Préserve le SRID si connu, sinon assigne 2154
  )
WHERE geom IS NOT NULL;