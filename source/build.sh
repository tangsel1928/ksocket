#!/bin/bash
set -e

echo "[*] Installing dependencies..."
apt-get install -y gcc autoconf automake libtool libssl-dev 2>/dev/null || \
yum install -y gcc autoconf automake libtool openssl-devel 2>/dev/null || \
echo "[!] Install dependencies manually: gcc autoconf automake libtool libssl-dev"

echo "[*] Bootstrap..."
./bootstrap

echo "[*] Configure..."
./configure

echo "[*] Compiling..."
make -j$(nproc)

echo "[*] Stripping binary..."
strip tools/gs-netcat

echo ""
echo "[+] Build selesai: tools/gs-netcat"
ls -lh tools/gs-netcat
file tools/gs-netcat

echo ""
echo "[*] Untuk generate file deploy & ks:"
echo "    bash pack.sh"
