from pathlib import Path

import fiona

from utils import download_file
from utils import unzip_7z
from utils import convert_gpkg_to_geojson


# Dossier de travail -----------------------------------------------------------
DATA_DIR = Path("./data").expanduser()
DATA_DIR.mkdir(parents=True, exist_ok=True)


if __name__ == "__main__":
    # URL du fichier compressé (.7z) à télécharger
    adminexpress_url = (
        "https://data.geopf.fr/telechargement/download/ADMIN-EXPRESS/"
        "ADMIN-EXPRESS_4-0__GPKG_WGS84G_FRA_2025-10-15/"
        "ADMIN-EXPRESS_4-0__GPKG_WGS84G_FRA_2025-10-15.7z"
    )

    # Chemins locaux pour le fichier compressé et pour l’extraction
    archive_path = DATA_DIR / "ADMIN-EXPRESS_4-0__GPKG_WGS84G_FRA_2025-10-15.7z"
    extraction_dir = DATA_DIR / "ADMIN-EXPRESS_4-0__GPKG_WGS84G_FRA_2025-10-15"

    # Étape 1 : Téléchargement du fichier ADMIN-EXPRESS
    # download_file(adminexpress_url, archive_path)
    print("✅ Téléchargement terminé :", archive_path)

    # Étape 2 : Décompression de l’archive
    # unzip_7z(archive_path, DATA_DIR)
    print("✅ Extraction terminée :", extraction_dir)

    # Répertoire contenant les shapefiles après extraction
    gpkg_file = (
        extraction_dir
        / "ADMIN-EXPRESS"
        / "1_DONNEES_LIVRAISON_2025-10-00141"
        / "ADE_4-0_GPKG_WGS84G_FRA-ED2025-10-15"
        / "ADE_4-0_GPKG_WGS84G_FRA-ED2025-10-15.gpkg"
    )

    layers = fiona.listlayers(gpkg_file)

    for layer in layers:
        if layer == "info_metadonnees":
            continue
        print("➡️  Conversion de la couche :", layer)
        convert_gpkg_to_geojson(gpkg_file, layer, DATA_DIR / f"{layer}.geojson")
        print("✅ Conversion terminée :", layer)
