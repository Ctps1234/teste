#!/system/bin/sh
# libperfmgr-hyperos - executado em post-fs-data
MODDIR=${0%/*}
. "$MODDIR/common/libperfmgr-common.sh"

pm_log_rotate
pm_log BOOT "post-fs-data: $(pm_android) soc=$(pm_soc)"

mkdir -p "$PERSIST" "$LOGDIR" "$DEBUG_HINT_DIR" 2>/dev/null

# se o utilizador desativou o HAL, garantir que nada fica a correr
if [ "$(pm_conf_get ENABLE_HAL 1)" != "1" ]; then
    pm_stop_hal
    pm_log BOOT "ENABLE_HAL=0 -> servico nao sera iniciado"
else
    # limpar propriedades de arranque para o caso de reinicio quente
    setprop vendor.powerhal.init ""
fi
