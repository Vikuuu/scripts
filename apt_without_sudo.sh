#!/usr/bin/env bash

# Fail early
set -euo pipefail

PACKAGE="${1:?Usage: $0 <package>}"

LOCAL_PREFIX="$HOME/local"
PACKAGE_DIR="$LOCAL_PREFIX/$PACKAGE"
BASHRC="$HOME/.bashrc"

# Create a local dir to store the downloaded `.deb` files.
mkdir -p "$PACKAGE_DIR"
cd "$PACKAGE_DIR"

# Download the packages and all of its dependencies
python3 - "$PACKAGE" <<'PY'
import subprocess
import sys
import re

package = sys.argv[1]

output = subprocess.check_output(
    ["apt-cache", "depends", package],
    text=True
)

packages = {package}

for line in output.splitlines():
    match = re.match(r"\s+Depends:\s+(\S+)", line)
    if match:
        packages.add(match.group(1))

packages = sorted(packages)

print("Packages: ")
for package in packages:
    print(f"   {package}")

subprocess.run(["apt-get", "download", *packages], check=True)
PY

# Extract all downloaded .deb packages
for deb in ./*.deb; do
    dpkg-deb -x "$deb" "$PACKAGE_DIR"
done

# --------------------------------------------
#     Add packages paths to ~/.bashrc
# --------------------------------------------

MARKER="# >>> local package: $PACKAGE >>>"
if ! grep -Fq "$MARKER" "$BASHRC"; then
    cat >> "$BASHRC" << EOF

$MARKER
export PATH="\$HOME/local/$PACKAGE/usr/bin:\$HOME/local/$PACKAGE/usr/sbin:\$PATH"
export LD_LIBRARY_PATH="\$HOME/local/$PACKAGE/usr/lib/x86_64-linux-gnu:\$HOME/local/$PACKAGE/lib/x86_64-linux-gnu:\$HOME/local/$PACKAGE/usr/lib:\$HOME/local/$PACKAGE/lib:\$LD_LIBRARY_PATH"
# <<< local package: $PACKAGE <<<
EOF
    
    echo
    echo "Added $PACKAGE to ~/.bashrc"
else
    echo "$PACKAGE is already configured in ~/.bashrc"
fi

echo
echo "Installed: $PACKAGE"
echo "Location: $PACKAGE_DIR"
echo
echo "Open a new shell or run:"
echo
echo "    source ~/.bashrc"
echo
