#!/usr/bin/env bash
# Removes the ms912x driver installed through DKMS.
# Usage: sudo bash uninstall.sh
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Error: please run as root: sudo bash $0" >&2
    exit 1
fi

NAME="ms912x"

for version in $(dkms status "$NAME" 2>/dev/null | sed -n "s|^$NAME/\([^,:]*\).*|\1|p" | sort -u); do
    echo "==> Removing $NAME/$version from DKMS..."
    dkms remove "$NAME/$version" --all
    rm -rf "/usr/src/$NAME-$version"
done

if [ -d "/sys/module/$NAME" ]; then
    echo "The module stays loaded until the next boot (or: sudo modprobe -r $NAME)."
fi
echo "Done."
