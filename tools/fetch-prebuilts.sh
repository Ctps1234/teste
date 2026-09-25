#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# libperfmgr-hyperos - (re)descarrega os binarios pre-compilados das duas
# variantes e verifica os SHA256.
#
#   api35 (Android 15, power AIDL V5)
#     Pixel "tokay" - tokay-user-15-AP4A.241205.013-12621605-release-keys
#     (patch 2024-12-05)
#
#   api36 (Android 16+, power AIDL V6)
#     Pixel 9 Pro "caiman" - generic_system_google-user-16-BP4A.260205.002-14624737-release-keys
#     (patch 2026-02-05)
#
#   ./tools/fetch-prebuilts.sh            descarrega e verifica
#   ./tools/fetch-prebuilts.sh --check    apenas verifica o que ja existe
#
# Necessita de curl + rede. Nao e necessario para instalar o modulo: os
# binarios ja vao versionados em prebuilt/.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

REPO35="gm-stuffs/google_tokay_dump"
BRANCH35="tokay-user-15-AP4A.241205.013-12621605-release-keys"
REPO36="gm-stuffs/google_caiman_dump"
BRANCH36="generic_system_google-user-16-BP4A.260205.002-14624737-release-keys"

# variante:caminho_no_dump:destino
FILES="
api35:vendor/lib64/libperfmgr.so:prebuilt/api35/lib64/libperfmgr.so
api35:vendor/lib64/libdisppower-pixel.so:prebuilt/api35/lib64/libdisppower-pixel.so
api35:vendor/lib64/pixel-power-ext-V1-ndk.so:prebuilt/api35/lib64/pixel-power-ext-V1-ndk.so
api35:vendor/lib64/android.hardware.power-V5-ndk.so:prebuilt/api35/lib64/android.hardware.power-V5-ndk.so
api35:vendor/bin/hw/android.hardware.power-service.pixel-libperfmgr:prebuilt/api35/bin/hw/android.hardware.power-service.pixel-libperfmgr
api35:vendor/bin/sendhint:prebuilt/api35/bin/sendhint
api35:vendor/etc/vintf/manifest/android.hardware.power-service.pixel.xml:prebuilt/api35/etc/vintf/manifest/android.hardware.power-service.pixel.xml
api35:vendor/etc/powerhint.json:prebuilt/api35/etc/powerhint.pixel.json
api35:vendor/etc/init/android.hardware.power-service.pixel-libperfmgr.rc:prebuilt/api35/etc/perfmgr/android.hardware.power-service.pixel-libperfmgr.rc
api36:vendor/lib64/libperfmgr.so:prebuilt/api36/lib64/libperfmgr.so
api36:vendor/lib64/libdisppower-pixel.so:prebuilt/api36/lib64/libdisppower-pixel.so
api36:vendor/lib64/pixel-power-ext-V1-ndk.so:prebuilt/api36/lib64/pixel-power-ext-V1-ndk.so
api36:vendor/lib64/android.hardware.power-V6-ndk.so:prebuilt/api36/lib64/android.hardware.power-V6-ndk.so
api36:vendor/lib64/android.hardware.thermal-V1-ndk.so:prebuilt/api36/lib64/android.hardware.thermal-V1-ndk.so
api36:vendor/bin/hw/android.hardware.power-service.pixel-libperfmgr:prebuilt/api36/bin/hw/android.hardware.power-service.pixel-libperfmgr
api36:vendor/bin/sendhint:prebuilt/api36/bin/sendhint
api36:vendor/etc/vintf/manifest/android.hardware.power-service.pixel.xml:prebuilt/api36/etc/vintf/manifest/android.hardware.power-service.pixel.xml
api36:vendor/etc/powerhint.json:prebuilt/api36/etc/powerhint.pixel.json
api36:vendor/etc/init/android.hardware.power-service.pixel-libperfmgr.rc:prebuilt/api36/etc/perfmgr/android.hardware.power-service.pixel-libperfmgr.rc
"

info() { printf '\033[1;34m  %s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
die() { printf '\033[1;31m  ✗ %s\033[0m\n' "$*" >&2; exit 1; }

if [ "${1:-}" = "--check" ]; then
    info "a verificar checksums"
    (cd prebuilt && sha256sum -c --quiet --ignore-missing SHA256SUMS) && ok "todos os ficheiros batem certo"
    exit 0
fi

command -v curl >/dev/null || die "curl nao encontrado"

for trio in $FILES; do
    var=${trio%%:*}
    rest=${trio#*:}
    src=${rest%%:*}
    dst=${rest#*:}
    if [ "$var" = api35 ]; then BASE="https://raw.githubusercontent.com/$REPO35/$BRANCH35"; else BASE="https://raw.githubusercontent.com/$REPO36/$BRANCH36"; fi
    mkdir -p "$(dirname "$dst")"
    printf '  %-14s %-52s' "$var" "$(basename "$dst")"
    curl -fsSL --retry 3 --connect-timeout 15 "$BASE/$src" -o "$dst" || die "falhou: $src"
    case "$dst" in
    */bin/* | *pixel-libperfmgr | *sendhint) chmod 0755 "$dst" ;;
    *) chmod 0644 "$dst" ;;
    esac
    echo "ok"
done

info "a verificar checksums"
(cd prebuilt && sha256sum -c --quiet --ignore-missing SHA256SUMS) ||
    die "ATENCAO: os ficheiros descarregados sao diferentes dos versionados"
ok "checksums verificados"
