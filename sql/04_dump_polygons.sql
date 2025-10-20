/*
 ================================================================================
 Décomposer les géométries MULTIPOLYGON en entités POLYGON individuelles.
 
 CONTEXTE :
 - On utilise ST_Dump pour "exploser" chaque MULTIPOLYGON en plusieurs POLYGONs (un par ligne).
 - Chaque partie reçoit un identifiant d'ordre (part_index) et un objet GeoJSON
 permettant un usage direct dans des applications web.
 
 RÉSULTAT :
 - Création d'une nouvelle table `public.zone_polygons`
 contenant une ligne par POLYGON issu du MULTIPOLYGON initial.
 - Colonnes :
 id              -- identifiant hérité de la table d'origine
 nom_zone        -- nom de la zone administrative
 geom_2154_part  -- géométrie POLYGON en SRID 2154
 feature         -- représentation GeoJSON (SRID 4326)
 
 ================================================================================
 */
-- Supprime la table si elle existe déjà, pour éviter les erreurs à la création
DROP TABLE IF EXISTS public.zone_polygons;
-- 1) Création d'une nouvelle table résultante
--    Décomposer chaque MULTIPOLYGON en parties via ST_Dump
CREATE TABLE public.zone_polygons AS WITH dumped AS (
  SELECT z.id,
    z.zone,
    (part).geom -- POLYGON
  FROM public.zone z
    CROSS JOIN LATERAL ST_Dump(zone.geom) AS part
    -- CROSS JOIN LATERAL ST_Dump(zone.geom_norm) AS part
) 
-- 2) : Sélectionner et enrichir les géométries extraites
SELECT id,
  nom_zone,
  geom,
  jsonb_build_object(
    'type',
    'Feature',
    'geometry',
    ST_AsGeoJSON(geom_part)::jsonb,
    'properties',
    jsonb_build_object()
  )::text AS feature
FROM dumped;