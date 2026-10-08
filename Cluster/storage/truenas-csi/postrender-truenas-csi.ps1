$ErrorActionPreference = "Stop"

$manifest = [Console]::In.ReadToEnd()

$pattern = '(?m)(name:\s*iscsi-dir\s*\n\s*hostPath:\s*\n\s*path:\s*/etc/iscsi\s*\n\s*type:\s*)Directory\b'
$matches = [regex]::Matches($manifest, $pattern)

if ($matches.Count -ne 1) {
    throw "Expected exactly one TrueNAS CSI iscsi-dir hostPath, found $($matches.Count)"
}

$patched = [regex]::Replace($manifest, $pattern, '${1}DirectoryOrCreate', 1)
[Console]::Out.Write($patched)
