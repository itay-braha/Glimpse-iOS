"""Exports the named UI-test screenshots from an .xcresult bundle with readable names.

Usage: python3 scripts/export-ui-attachments.py TestResults.xcresult out-dir
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile


def main(bundle: str, out_dir: str) -> None:
    raw = tempfile.mkdtemp()
    subprocess.run(
        ["xcrun", "xcresulttool", "export", "attachments", "--path", bundle, "--output-path", raw],
        check=True,
    )
    with open(os.path.join(raw, "manifest.json"), encoding="utf-8") as handle:
        manifest = json.load(handle)

    os.makedirs(out_dir, exist_ok=True)
    count = 0
    for test in manifest:
        for attachment in test.get("attachments", []):
            exported = attachment.get("exportedFileName")
            name = attachment.get("suggestedHumanReadableName") or exported
            if not exported:
                continue
            # "1-2 Phone number_0_<uuid>.png" -> "1-2 Phone number.png"
            clean = re.sub(r"_\d+_[0-9A-F-]{36}", "", name, flags=re.IGNORECASE)
            shutil.copy(os.path.join(raw, exported), os.path.join(out_dir, clean))
            count += 1
    print(f"exported {count} screenshots to {out_dir}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
