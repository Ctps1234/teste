#!/system/bin/sh
# libperfmgr-hyperos - executado quando o arranque termina
MODDIR=${0%/*}
. "$MODDIR/common/libperfmgr-common.sh"

pm_log BOOT "boot-completed"

if [ "$(pm_conf_get ENABLE_HAL 1)" = "1" ]; then
    if [ "$(pm_conf_get ENABLE_HINTS 0)" = "1" ]; then
        pm_enable_hints 1
    else
        pm_enable_hints 0
        pm_log HINTS "desativadas: o HAL responde apenas a ADPF/hint sessions"
    fi
fi

pm_log BOOT "estado final:"
pm_status_line >>"$LOGFILE" 2>/dev/null

# diagnostico util: o HAL esta a ser visto pelo framework?
if pm_hal_registered; then
    pm_log BOOT "powerstats/HAL pronto. Teste manual: sendhint LAUNCH"
else
    pm_log WARN "HAL nao registado - verifique o log e o metamodulo"
fi
