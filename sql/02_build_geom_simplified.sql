/*
 ================================================================================
 1) Projeter la géométrie en Lambert-93 (EPSG:2154) `geom_2154`
 2) Simplifier topologiquement cette géométrie (tolérance métrique, e.g. 500m)
 3) Projeter en WGS84 (EPSG:4326) 
 
 REMARQUES :
 - EPSG:2154 est en mètres : la tolérance de simplification est en mètres.
 - ST_SimplifyPreserveTopology conserve les relations.
 - 500 m de tolérance est très élevé : à ajuster selon l’échelle d’usage.
 
 Résultat :
 - Une nouvelle colonne `geom_simplified` : MULTIPOLYGON en EPSG:4326 (WGS84) simplifié
 ================================================================================
 */
-- 1) Créer la colonne `geom_simplified`
ALTER TABLE public.zone
  ADD COLUMN IF NOT EXISTS geom_simplified geometry(MultiPolygon, 4326);
UPDATE public.zone
SET geom_2154 = ST_Transform(geom_norm, 2154)
WHERE geom_norm IS NOT NULL;
-- 2) Simplification topologique (tolérance en mètres, ici 500 m)
--    en passant par une projection EPSG:2154 'Lambert-93'
--    Ajuster la tolérance selon l’usage (ex : 50 m pour zoom urbain, 200–500 m pour France entière).
UPDATE public.zone
SET geom_simplified = ST_Transform(ST_SimplifyPreserveTopology(ST_Transform(geom_norm, 2154), 500::double precision), 4326)
WHERE geom_norm IS NOT NULL;