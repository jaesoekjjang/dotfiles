#!/bin/bash
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit
exec python3 "$script_dir/clipboard.py" files "$PWD" "$@"
