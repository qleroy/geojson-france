from typing import Optional
from pathlib import Path

import requests
import py7zr
import geopandas as gpd
from shapely import affinity


# Dossier de travail -----------------------------------------------------------
DATA_DIR = Path("./data").expanduser()
DATA_DIR.mkdir(parents=True, exist_ok=True)


# Utilitaires E/S --------------------------------------------------------------
def download_file(url: str, dest_path: Path, chunk_size: int = 8192) -> Path:
    """
    Télécharge un fichier en streaming vers dest_path.

    Args:
        url: URL du fichier à télécharger.
        dest_path: chemin local de sortie (répertoires créés si besoin).
        chunk_size: taille des blocs d'écriture.

    Returns:
        Le chemin du fichier téléchargé.
    """
    dest_path = Path(dest_path)
    dest_path.parent.mkdir(parents=True, exist_ok=True)

    with requests.get(url, stream=True) as resp:
        resp.raise_for_status()
        with dest_path.open("wb") as f:
            for chunk in resp.iter_content(chunk_size=chunk_size):
                if chunk:
                    f.write(chunk)
    return dest_path


def unzip_7z(archive_path: Path, extract_dir: Path) -> Path:
    """
    Décompresse une archive .7z dans un dossier cible.

    Args:
        archive_path: chemin de l'archive .7z
        extract_dir: dossier de destination

    Returns:
        Le dossier d'extraction.
    """
    archive_path = Path(archive_path)
    extract_dir = Path(extract_dir)
    extract_dir.mkdir(parents=True, exist_ok=True)

    with py7zr.SevenZipFile(archive_path, mode="r") as z:
        z.extractall(path=extract_dir)

    return extract_dir


def convert_gpkg_to_geojson(gpkg_path: Path, layer: str, geojson_path: Path) -> Path:
    """
    Charge un gpkg et l’exporte en GeoJSON.

    Args:
        gpkg_path: chemin vers le .gpkg
        layer: nom de la couche
        geojson_path: chemin de sortie .geojson

    Returns:
        Le chemin du GeoJSON écrit.
    """
    gpkg_path = Path(gpkg_path)
    geojson_path = Path(geojson_path)
    geojson_path.parent.mkdir(parents=True, exist_ok=True)

    gdf = gpd.read_file(gpkg_path, layer=layer)
    gdf.to_file(geojson_path, driver="GeoJSON")
    return geojson_path


def save_as_geojson(gdf, keep_columns, output_filename):
    """
    Sélectionne certaines colonnes d’un GeoDataFrame et les exporte en GeoJSON.

    Args:
        gdf: GeoDataFrame source.
        keep_columns: liste des colonnes à conserver (y compris 'geometry').
        output_filename: nom du fichier de sortie (dans DATA_DIR).
    """
    simplified = gdf[keep_columns].copy()
    output_path = DATA_DIR / output_filename
    simplified.to_file(output_path, driver="GeoJSON")
    print(f"✅ GeoJSON simplifié sauvegardé : {output_path}")


# Géométrie / carto ------------------------------------------------------------
def reposition(
    gdf: gpd.GeoDataFrame,
    idx,  # index, liste d'index ou masque booléen sélectionnant les entités à déplacer
    xoff: Optional[float] = None,
    yoff: Optional[float] = None,
    xscale: Optional[float] = None,
    yscale: Optional[float] = None,
    simplify: Optional[float] = None,
) -> gpd.GeoDataFrame:
    """
    Mise à l’échelle et translation d’un sous-ensemble de géométries autour de leur centroïde commun.

    - Le centroïde d'origine est calculé sur l’union des géométries sélectionnées.
    - L’échelle est appliquée avant la translation.
    - La simplification (si fournie) intervient à la fin (preserve_topology=False).

    Args:
        gdf: GeoDataFrame source.
        idx: indices/masque pour sélectionner les lignes à transformer.
        xoff, yoff: décalages (en unités du CRS) à appliquer.
        xscale, yscale: facteurs d’échelle (1 = inchangé).
        simplify: tolérance pour la simplification (None = pas de simplification).

    Returns:
        Un nouveau GeoDataFrame avec les géométries modifiées.
    """
    # union des géométries sélectionnées pour obtenir un point d’ancrage robuste
    anchor = gdf.loc[idx, "geometry"].union_all().centroid

    def _transform(geom):
        out = geom
        if xscale is not None or yscale is not None:
            out = affinity.scale(
                out, xfact=xscale or 1, yfact=yscale or 1, origin=anchor
            )
        if xoff is not None or yoff is not None:
            out = affinity.translate(out, xoff or 0, yoff or 0)
        if simplify is not None and simplify > 0:
            out = out.simplify(simplify, preserve_topology=False)
        return out

    res = gdf.copy()
    res.loc[idx, "geometry"] = res.loc[idx, "geometry"].apply(_transform)
    return res
