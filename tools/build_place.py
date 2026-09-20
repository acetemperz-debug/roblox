#!/usr/bin/env python3
"""Build Roblox files from the source tree.

    python3 tools/build_place.py

Writes two things into build/:

  MacrosoftSupport.rbxlx   A whole place. Studio opens it directly and
                           everything is already in the right service, so
                           testing is "open the file, press Play". Opening it
                           replaces whatever place you had open.

  MacrosoftSupport.rbxmx   A model, for adding the game to an EXISTING place.
                           Right-click in Explorer, Insert from File, then drag
                           the three folders where the labels say.

Both are Roblox's XML format. Scripts are Items carrying a ProtectedString
"Source" property; anything not listed falls back to Studio's defaults, so only
the services that actually hold something need to appear.

There is deliberately no "paste it all into the command bar" output: the source
is ~370 KB and the command bar is a single-line box, so it would be truncated.
"""
import html
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PLACE_OUT = ROOT / "build" / "MacrosoftSupport.rbxlx"
MODEL_OUT = ROOT / "build" / "MacrosoftSupport.rbxmx"
MANIFEST_OUT = ROOT / "build" / "manifest.json"

XML_HEADER = (
    '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" '
    'version="4">\n'
)

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


def folder_item(name: str, indent: str, children: str) -> str:
    return (
        f'{indent}<Item class="Folder" referent="{next_referent()}">\n'
        f"{indent}\t<Properties>\n"
        f'{indent}\t\t<string name="Name">{html.escape(name)}</string>\n'
        f"{indent}\t</Properties>\n"
        f"{children}"
        f"{indent}</Item>\n"
    )


def build_model() -> str:
    """One Folder holding three labelled folders, for Insert from File."""
    parts = [XML_HEADER]

    inner = []
    for entry in LAYOUT:
        files = sources_in(entry["path"])
        scripts = "".join(script_item(file, "\t\t\t") for file in files)
        # The client files must end up as direct children of
        # StarterPlayerScripts, so the folder name says so.
        label = entry["folder"] or "DRAG_MY_CONTENTS_INTO_StarterPlayerScripts"
        inner.append(folder_item(label, "\t\t", scripts))

    parts.append(folder_item("MacrosoftSupport", "\t", "".join(inner)))
    parts.append("</roblox>\n")
    return "".join(parts)


def build() -> str:
    parts = [XML_HEADER]

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


def build_manifest() -> str:
    """File list for tools/StudioLoader.lua, which installs over HTTP."""
    targets = {"shared": "shared", "server": "server", "client": "client"}
    entries = []
    for key in ("shared", "server", "client"):
        for file in sources_in(ROOT / "src" / key):
            class_name, name = class_and_name(file)
            entries.append(
                {
                    "path": f"src/{key}/{file.name}",
                    "name": name,
                    "class": class_name,
                    "target": targets[key],
                }
            )
    return json.dumps({"version": 1, "files": entries}, indent="\t") + "\n"


if __name__ == "__main__":
    PLACE_OUT.parent.mkdir(parents=True, exist_ok=True)
    PLACE_OUT.write_text(build())
    print(f"wrote {PLACE_OUT.relative_to(ROOT)} ({PLACE_OUT.stat().st_size // 1024} KB)")
    MODEL_OUT.write_text(build_model())
    print(f"wrote {MODEL_OUT.relative_to(ROOT)} ({MODEL_OUT.stat().st_size // 1024} KB)")
    MANIFEST_OUT.write_text(build_manifest())
    print(f"wrote {MANIFEST_OUT.relative_to(ROOT)}")
