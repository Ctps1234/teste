#!/system/bin/sh
# libperfmgr-hyperos - executado antes de o modulo ser removido
MODDIR=${0%/*}
. "$MODDIR/common/libperfmgr-common.sh"

pm_log UNINSTALL "a remover modulo"

pm_stop_hal

# limpar propriedades alteradas
setprop vendor.powerhal.init ""
setprop vendor.powerhal.config.debug false
setprop vendor.powerhal.state ""
setprop vendor.powerhal.audio ""
setprop vendor.powerhal.rendering ""

# limpar a copia depuravel do ficheiro de hints
rm -f "$DEBUG_HINT" 2>/dev/null

pm_log UNINSTALL "removido. Configuracao e registos mantidos em $PERSIST"
