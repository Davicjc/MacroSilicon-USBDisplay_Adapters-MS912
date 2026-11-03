#!/usr/bin/env bash
# Instala o driver ms912x pelo DKMS (recompila sozinho a cada kernel novo).
# Uso: sudo bash instalar.sh
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Erro: execute como administrador: sudo bash $0" >&2
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOME="ms912x"
VERSAO="$(sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' "$DIR/dkms.conf")"
KVER="$(uname -r)"
SRC="/usr/src/$NOME-$VERSAO"

for cmd in dkms make; do
    command -v "$cmd" >/dev/null || {
        echo "Erro: '$cmd' não encontrado. Instale: sudo apt install dkms build-essential" >&2
        exit 1
    }
done
if [ ! -d "/lib/modules/$KVER/build" ]; then
    echo "Erro: headers do kernel $KVER ausentes. Instale: sudo apt install linux-headers-$KVER" >&2
    exit 1
fi

echo "==> [1/4] Removendo versões antigas do $NOME..."
for antiga in $(dkms status "$NOME" 2>/dev/null | sed -n "s|^$NOME/\([^,:]*\).*|\1|p" | sort -u); do
    dkms remove "$NOME/$antiga" --all
done
# Cópia manual deixada pelo script antigo (fora do controle do DKMS)
if [ -f "/lib/modules/$KVER/updates/$NOME.ko" ] && [[ "$(dkms status "$NOME" 2>/dev/null)" != *installed* ]]; then
    rm -f "/lib/modules/$KVER/updates/$NOME.ko"
fi

echo "==> [2/4] Copiando o código-fonte para $SRC..."
rm -rf "$SRC"
install -d "$SRC"
install -m 644 "$DIR"/*.c "$DIR"/*.h "$DIR/Makefile" "$DIR/dkms.conf" "$DIR/LICENSE" "$SRC/"

echo "==> [3/4] Compilando e instalando pelo DKMS (kernel $KVER)..."
dkms add "$NOME/$VERSAO"
dkms build "$NOME/$VERSAO" -k "$KVER"
dkms install "$NOME/$VERSAO" -k "$KVER"

echo "==> [4/4] Carregando o driver..."
if [ -d "/sys/module/$NOME" ]; then
    echo "O $NOME já está carregado. A versão instalada vale a partir do próximo boot"
    echo "(ou tire e recoloque o adaptador USB depois de: sudo modprobe -r $NOME)."
else
    modprobe "$NOME"
fi

echo
dkms status "$NOME"
echo "Pronto."
