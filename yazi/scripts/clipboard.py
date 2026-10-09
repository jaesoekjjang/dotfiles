#!/usr/bin/env python3
"""Copy selected local files or their names/paths without shell interpolation."""

import os
from pathlib import Path
import subprocess
import sys


def main():
    mode, cwd, *paths = sys.argv[1:]
    if not paths:
        raise ValueError("No file selected")
    if mode == "files":
        for path in paths:
            if not Path(path).exists():
                raise ValueError(f"File no longer exists: {path}")
        subprocess.run(
            ["/usr/bin/osascript", "-l", "JavaScript",
             str(Path(__file__).with_name("copy-files.js")), *paths],
            check=True, capture_output=True, text=True,
        )
        label = f"{len(paths)} file(s): " + ", ".join(Path(p).name for p in paths)
    else:
        if mode == "filename":
            values = [Path(p).name for p in paths]
        elif mode == "path":
            values = [os.path.abspath(p) for p in paths]
        elif mode == "relative":
            values = [os.path.relpath(p, cwd) for p in paths]
        else:
            raise ValueError(f"Unknown copy mode: {mode}")
        subprocess.run(["pbcopy"], input="\n".join(values).encode("utf-8"), check=True)
        label = "\n".join(values)
    print(label)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stderr or str(error), file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
