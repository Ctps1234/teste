#!/system/bin/sh
export LD_LIBRARY_PATH=/system/lib64:/vendor/lib64:$LD_LIBRARY_PATH
exec /vendor/bin/sendhint.bin "$@"
