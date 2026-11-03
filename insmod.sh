#!/usr/bin/env bash
# Teste rápido: compila e carrega o driver desta pasta, sem instalar.
# Some no próximo boot. Para instalar de vez, use: sudo bash instalar.sh
# Se o rmmod falhar com "in use", tire o adaptador USB (ou faça logout) e rode de novo.
set -e
make clean
make all -j"$(nproc)"
sudo rmmod ms912x 2>/dev/null || true
sudo insmod ms912x.ko
