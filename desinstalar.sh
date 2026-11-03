#!/usr/bin/env bash
# Remove o driver ms912x instalado pelo DKMS.
# Uso: sudo bash desinstalar.sh
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Erro: execute como administrador: sudo bash $0" >&2
    exit 1
fi

NOME="ms912x"

for versao in $(dkms status "$NOME" 2>/dev/null | sed -n "s|^$NOME/\([^,:]*\).*|\1|p" | sort -u); do
    echo "==> Removendo $NOME/$versao do DKMS..."
    dkms remove "$NOME/$versao" --all
    rm -rf "/usr/src/$NOME-$versao"
done

if [ -d "/sys/module/$NOME" ]; then
    echo "O módulo continua carregado até o próximo boot (ou: sudo modprobe -r $NOME)."
fi
echo "Pronto."
