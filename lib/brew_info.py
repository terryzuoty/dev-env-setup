"""Turn `brew info --json=v2` output into one tab-separated line per requested name.

Usage: brew info --json=v2 --<kind> NAMES | python3 brew_info.py <formula|cask> NAMES

Columns: requested, found|missing, canonical name, installed (0/1), installed on request (0/1),
needs admin password (0/1), app bundles, binaries, font files (lists joined with "|", "-" if none).
"""

import json
import os
import sys

# Casks that install fonts through a .pkg, so their JSON lists no font files to look for.
PKG_FONTS = {"font-sf-mono": ["SF-Mono-Regular.otf"]}
CLEANUP_STANZAS = {"zap", "uninstall", "uninstall_preflight", "uninstall_postflight"}


def target_name(values):
    if len(values) > 1 and isinstance(values[1], dict) and values[1].get("target"):
        return os.path.basename(values[1]["target"])
    return os.path.basename(str(values[0]))


def formula_row(req, f):
    installed = f.get("installed") or []
    on_request = bool(installed and installed[0].get("installed_on_request"))
    return [req, "found", f["name"], int(bool(installed)), int(on_request), 0, "", "", ""]


def cask_row(req, c):
    apps, bins, fonts, admin = [], [], [], False
    for artifact in c.get("artifacts", []):
        for key, values in artifact.items():
            if key in CLEANUP_STANZAS:
                continue
            if key == "pkg":
                admin = True
            if "/usr/local/" in json.dumps(values):
                admin = True
            if not isinstance(values, list) or not values:
                continue
            if key == "app":
                apps.append(target_name(values))
            elif key == "binary":
                bins.append(target_name(values))
            elif key == "font":
                fonts.append(target_name(values))
    fonts += PKG_FONTS.get(c["token"], [])
    return [req, "found", c["token"], int(bool(c.get("installed"))), 1, int(admin),
            "|".join(apps), "|".join(bins), "|".join(fonts)]


def names_of(entry, kind):
    if kind == "formula":
        return {entry.get("name"), entry.get("full_name"), *entry.get("aliases", []), *entry.get("oldnames", [])}
    return {entry.get("token"), entry.get("full_token"), *entry.get("old_tokens", [])}


def main():
    kind, requested = sys.argv[1], sys.argv[2:]
    data = json.load(sys.stdin)
    entries = data["formulae"] if kind == "formula" else data["casks"]
    for req in requested:
        match = next((e for e in entries if req in names_of(e, kind)), None)
        if match is None:
            row = [req, "missing", "", 0, 0, 0, "", "", ""]
        elif kind == "formula":
            row = formula_row(req, match)
        else:
            row = cask_row(req, match)
        # "-" stands in for empty fields: bash `read` collapses consecutive tabs.
        print("\t".join(str(v) if v != "" else "-" for v in row))


if __name__ == "__main__":
    main()
