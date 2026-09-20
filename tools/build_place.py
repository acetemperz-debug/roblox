#!/usr/bin/env python3
"""Build a ready-to-open Roblox place file from the source tree.

    python3 tools/build_place.py

Writes build/MacrosoftSupport.rbxlx, which Studio opens directly: everything is
already in the right service, so testing is "open the file, press Play".

The .rbxlx format is Roblox's XML place format. Scripts are Items carrying a
ProtectedString "Source" property; anything not listed falls back to Studio's
defaults, so only the services that actually hold something need to appear.
"""
import html
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "MacrosoftSupport.rbxlx"

# Where each source folder lands, and what the container is called.
LAYOUT = [
    {
        "service": "ReplicatedStorage",
        "folder": "MacrosoftShared",
        "path": ROOT / "src" / "shared",
    },
    {
        "service": "ServerScriptService",
        "folder": "MacrosoftServer",
        "path": ROOT / "src" / "server",
    },
    {
        # StarterPlayerScripts is a child of the StarterPlayer service, and the
        # three client files sit directly inside it as siblings.
        "service": "StarterPlayer",
        "child_service": "StarterPlayerScripts",
        "folder": None,
        "path": ROOT / "src" / "client",
    },
]

_referent = 0


def next_referent() -> str:
    global _referent
    _referent += 1
    return f"RBX{_referent}"


def class_and_name(path: pathlib.Path):
    """Map a filename to its Roblox class and instance name."""
    stem = path.name
    if stem.endswith(".server.luau"):
        return "Script", stem[: -len(".server.luau")]
    if stem.endswith(".client.luau"):
        return "LocalScript", stem[: -len(".client.luau")]
    return "ModuleScript", stem[: -len(".luau")]


def cdata(source: str) -> str:
    # A CDATA section cannot contain "]]>". None of ours do, but splitting the
    # sequence keeps the generator correct if that ever changes.
    safe = source.replace("]]>", "]]]]><![CDATA[>")
    return f"<![CDATA[{safe}]]>"


def script_item(path: pathlib.Path, indent: str) -> str:
    class_name, name = class_and_name(path)
    source = path.read_text()
    return (
        f'{indent}<Item class="{class_name}" referent="{next_referent()}">\n'
        f"{indent}\t<Properties>\n"
        f'{indent}\t\t<string name="Name">{html.escape(name)}</string>\n'
        f'{indent}\t\t<ProtectedString name="Source">{cdata(source)}</ProtectedString>\n'
        f"{indent}\t</Properties>\n"
        f"{indent}</Item>\n"
    )


def sources_in(path: pathlib.Path):
    return sorted(path.glob("*.luau"))


def build() -> str:
    parts = [
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" '
        'version="4">\n'
    ]

    total = 0
    for entry in LAYOUT:
        files = sources_in(entry["path"])
        if not files:
            print(f"warning: no .luau files in {entry['path']}", file=sys.stderr)
        total += len(files)

        parts.append(f'\t<Item class="{entry["service"]}" referent="{next_referent()}">\n')
        parts.append("\t\t<Properties>\n")
        parts.append(f'\t\t\t<string name="Name">{entry["service"]}</string>\n')
        parts.append("\t\t</Properties>\n")

        indent = "\t\t"
        if entry.get("child_service"):
            parts.append(f'\t\t<Item class="{entry["child_service"]}" referent="{next_referent()}">\n')
            parts.append("\t\t\t<Properties>\n")
            parts.append(f'\t\t\t\t<string name="Name">{entry["child_service"]}</string>\n')
            parts.append("\t\t\t</Properties>\n")
            indent = "\t\t\t"

        if entry["folder"]:
            parts.append(f'{indent}<Item class="Folder" referent="{next_referent()}">\n')
            parts.append(f"{indent}\t<Properties>\n")
            parts.append(f'{indent}\t\t<string name="Name">{entry["folder"]}</string>\n')
            parts.append(f"{indent}\t</Properties>\n")
            for file in files:
                parts.append(script_item(file, indent + "\t"))
            parts.append(f"{indent}</Item>\n")
        else:
            for file in files:
                parts.append(script_item(file, indent))

        if entry.get("child_service"):
            parts.append("\t\t</Item>\n")
        parts.append("\t</Item>\n")

    parts.append("</roblox>\n")
    print(f"packed {total} scripts")
    return "".join(parts)


if __name__ == "__main__":
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(build())
    print(f"wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")
