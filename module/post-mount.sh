#!/system/bin/sh
# libperfmgr-hyperos - executado depois da montagem do sistema de ficheiros
# do modulo (overlayfs / magic mount). E aqui que etiquetamos os ficheiros.
MODDIR=${0%/*}
. "$MODDIR/common/libperfmgr-common.sh"

pm_log BOOT "post-mount: a etiquetar ficheiros"

# 1. verificar se a pasta system/ do modulo foi mesmo montada
if [ ! -f /vendor/lib64/libperfmgr.so ]; then
    pm_log WARN "libperfmgr.so NAO visivel em /vendor/lib64"
    pm_log WARN "causa provavel: KernelSU sem metamodulo de montagem (meta-overlayfs)"
    pm_log WARN "instale o meta-overlayfs e reinicie"
else
    pm_log BOOT "libperfmgr.so montada em /vendor/lib64"
fi

# 2. permissoes e contexto SELinux
pm_label_files

# 3. espaco para a configuracao depuravel do libperfmgr
mkdir -p "$DEBUG_HINT_DIR" 2>/dev/null
[ -d "$DEBUG_HINT_DIR" ] && chmod 0755 "$DEBUG_HINT_DIR" 2>/dev/null

pm_log BOOT "post-mount concluido"
