#!/usr/bin/env bash
set -euo pipefail

python3 -c '
import re
import sys

manifest = sys.stdin.read()

pattern = re.compile(
    r"(name:\s*iscsi-dir\s*\n"
    r"\s*hostPath:\s*\n"
    r"\s*path:\s*/etc/iscsi\s*\n"
    r"\s*type:\s*)Directory\b"
)

patched, count = pattern.subn(r"\1DirectoryOrCreate", manifest, count=1)

if count != 1:
    raise SystemExit(
        f"Expected exactly one TrueNAS CSI iscsi-dir hostPath, found {count}"
    )

sys.stdout.write(patched)
'
