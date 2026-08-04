#!/usr/bin/env python3
"""
Build Party Finder into a Machine Party Mod Loader ready zip.

Party Finder is pure GDScript, so there is no compile step. "Building" just means
packaging the mod folder into a zip with the layout the mod loader expects:

    dist/Jaxon-PartyFinder.zip
      mods-unpacked/Jaxon-PartyFinder/manifest.json
      mods-unpacked/Jaxon-PartyFinder/mod_main.gd
      mods-unpacked/Jaxon-PartyFinder/...

Usage:
    python build.py
"""
import os
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
MOD_ID = "Jaxon-PartyFinder"
SRC = os.path.join(HERE, MOD_ID)
OUT_DIR = os.path.join(HERE, "dist")
OUT = os.path.join(OUT_DIR, MOD_ID + ".zip")


def main() -> None:
    if not os.path.isdir(SRC):
        raise SystemExit("Cannot find mod source folder: " + SRC)

    os.makedirs(OUT_DIR, exist_ok=True)
    if os.path.exists(OUT):
        os.remove(OUT)

    count = 0
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _dirs, files in os.walk(SRC):
            for fn in files:
                full = os.path.join(root, fn)
                rel = os.path.relpath(full, SRC).replace("\\", "/")
                z.write(full, "mods-unpacked/" + MOD_ID + "/" + rel)
                count += 1

    print("Built " + OUT + " (" + str(count) + " files)")


if __name__ == "__main__":
    main()
