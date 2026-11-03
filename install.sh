#!/usr/bin/env bash
# Installs the ms912x driver through DKMS (rebuilt automatically for new kernels).
# Usage: sudo bash install.sh
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Error: please run as root: sudo bash $0" >&2
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="ms912x"
VERSION="$(sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' "$DIR/dkms.conf")"
KVER="$(uname -r)"
SRC="/usr/src/$NAME-$VERSION"

for cmd in dkms make; do
    command -v "$cmd" >/dev/null || {
        echo "Error: '$cmd' not found. Install: sudo apt install dkms build-essential" >&2
        exit 1
    }
done
if [ ! -d "/lib/modules/$KVER/build" ]; then
    echo "Error: kernel headers for $KVER missing. Install: sudo apt install linux-headers-$KVER" >&2
    exit 1
fi

echo "==> [1/4] Removing old $NAME versions..."
for old in $(dkms status "$NAME" 2>/dev/null | sed -n "s|^$NAME/\([^,:]*\).*|\1|p" | sort -u); do
    dkms remove "$NAME/$old" --all
done
# Manual copy left by the old script (not tracked by DKMS)
if [ -f "/lib/modules/$KVER/updates/$NAME.ko" ] && [[ "$(dkms status "$NAME" 2>/dev/null)" != *installed* ]]; then
    rm -f "/lib/modules/$KVER/updates/$NAME.ko"
fi

echo "==> [2/4] Copying sources to $SRC..."
rm -rf "$SRC"
install -d "$SRC"
install -m 644 "$DIR"/*.c "$DIR"/*.h "$DIR/Makefile" "$DIR/dkms.conf" "$DIR/LICENSE" "$SRC/"

echo "==> [3/4] Building and installing through DKMS (kernel $KVER)..."
dkms add "$NAME/$VERSION"
dkms build "$NAME/$VERSION" -k "$KVER"
dkms install "$NAME/$VERSION" -k "$KVER"

echo "==> [4/4] Loading the driver..."
if [ -d "/sys/module/$NAME" ]; then
    echo "$NAME is already loaded. The installed version is used from the next boot"
    echo "(or replug the USB adapter after: sudo modprobe -r $NAME)."
else
    modprobe "$NAME"
fi

echo
dkms status "$NAME"
echo "Done."
