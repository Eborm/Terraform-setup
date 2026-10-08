#!/usr/bin/env bash
set -euo pipefail

awk '
{
    if ($0 ~ /^[[:space:]]*-[[:space:]]*name:[[:space:]]*iscsi-dir[[:space:]]*$/) {
        iscsi = 1
        hostpath = 0
        iscsi_path = 0
    }
    else if (iscsi && $0 ~ /^[[:space:]]*hostPath:[[:space:]]*$/) {
        hostpath = 1
    }
    else if (iscsi && hostpath && $0 ~ /^[[:space:]]*path:[[:space:]]*\/etc\/iscsi[[:space:]]*$/) {
        iscsi_path = 1
    }
    else if (iscsi && hostpath && iscsi_path &&
             $0 ~ /^[[:space:]]*type:[[:space:]]*Directory[[:space:]]*$/) {
        sub(/Directory[[:space:]]*$/, "DirectoryOrCreate")
        found++
        iscsi = 0
        hostpath = 0
        iscsi_path = 0
    }
    else if (iscsi && $0 ~ /^[[:space:]]*-[[:space:]]*name:/) {
        iscsi = 0
        hostpath = 0
        iscsi_path = 0
    }

    print
}

END {
    if (found != 1) {
        print "Expected exactly one TrueNAS CSI iscsi-dir hostPath to patch, found " found > "/dev/stderr"
        exit 1
    }
}
'