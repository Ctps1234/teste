#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# libperfmgr-hyperos - constroi o ZIP flashavel a partir de module/ + prebuilt/
#
#   ./build.sh            -> out/libperfmgr-hyperos-v<versao>.zip
#   ./build.sh --no-zip   -> apenas monta a arvore em out/<id>/
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

MODID=libperfmgr-hyperos
VERSION=$(sed -n 's/^version=//p' module/module.prop)
VERSIONCODE=$(sed -n 's/^versionCode=//p' module/module.prop)
OUT="$ROOT/out"
STAGE="$OUT/$MODID"
ZIP="$OUT/${MODID}-${VERSION}.zip"

info() { printf '\033[1;34m  %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m  ✗ %s\033[0m\n' "$*" >&2; exit 1; }

command -v zip >/dev/null || die "o comando 'zip' nao esta instalado"

# ---------------------------------------------------------------------------
info "a verificar os binarios em prebuilt/"
[ -f prebuilt/SHA256SUMS ] || die "prebuilt/SHA256SUMS em falta (corra ./tools/fetch-prebuilts.sh)"
( cd prebuilt && sha256sum -c --quiet --ignore-missing SHA256SUMS ) \
  || die "checksum dos prebuilts nao bate certo"

# ---------------------------------------------------------------------------
info "a montar a arvore do modulo"
rm -rf "$STAGE"
mkdir -p "$STAGE"

cp -a module/. "$STAGE"/

# as duas variantes de binarios (Android 15 = power AIDL V5, Android 16+ = V6)
# ficam dentro do zip; e o customize.sh que escolhe a adequada ao dispositivo
mkdir -p "$STAGE/prebuilt"
cp -a prebuilt/. "$STAGE/prebuilt/"
rm -f "$STAGE/prebuilt/SHA256SUMS"

# estrutura minima que o customize.sh vai preencher
mkdir -p "$STAGE/system/vendor/lib64" \
         "$STAGE/system/vendor/bin/hw" \
         "$STAGE/system/vendor/etc/perfmgr" \
         "$STAGE/system/vendor/etc/vintf/manifest"

# permissoes dos scripts
chmod 0755 "$STAGE"/*.sh "$STAGE"/common/*.sh 2>/dev/null || true
chmod 0644 "$STAGE"/module.prop "$STAGE"/sepolicy.rule "$STAGE"/system.prop "$STAGE"/perfmgr.conf 2>/dev/null || true
find "$STAGE" -name '.gitkeep' -delete 2>/dev/null || true
ok "arvore pronta em out/$MODID"

# ---------------------------------------------------------------------------
if [ "${1:-}" = "--no-zip" ]; then
  ok "--no-zip: zip nao gerado"
  exit 0
fi

info "a gerar $ZIP"
rm -f "$ZIP"
mkdir -p "$STAGE/META-INF/com/google/android"
printf '#MAGISK\n' > "$STAGE/META-INF/com/google/android/update-binary"
printf '#MAGISK\n' > "$STAGE/META-INF/com/google/android/updater-script"

( cd "$STAGE" && zip -r -q -9 -X "$ZIP" . -x '*.gitkeep' )
ok "zip: $ZIP ($(du -h "$ZIP" | cut -f1))"

# ---------------------------------------------------------------------------
# update.json para as atualizacoes pelo gestor
if [ -n "${REPO_URL:-}" ]; then
  ZIP_URL="$REPO_URL/releases/latest/download/$(basename "$ZIP")"
  cat > "$ROOT/update.json" <<JSON
{
  "version": "$VERSION",
  "versionCode": $VERSIONCODE,
  "zipUrl": "$ZIP_URL",
  "changelog": "$REPO_URL/blob/main/CHANGELOG.md"
}
JSON
  ok "update.json gerado"
fi

echo
ok "concluido. Instale pelo gestor (KernelSU / KernelSU Next / Magisk / APatch)."
