#!/system/bin/sh
# ---------------------------------------------------------------------------
# libperfmgr-hyperos - gerador de powerhint.json adaptado ao dispositivo
#
# Constroi um ficheiro de hints valido para o libperfmgr usando APENAS nos
# que realmente existem e sao gravaveis neste kernel/ROM.
#
# Regras importantes deduzidas do HintManager.cc (AOSP):
#   * "Nodes" vazio    -> HintManager devolve nullptr -> o servico morre (FATAL)
#   * "Actions" vazio  -> idem
#   * valores duplicados dentro de um no -> falha o parse
#   * uma Action tem de referenciar um no existente e um valor desse no
#   * (hint, no) nao pode repetir-se
# Por isso este gerador garante sempre pelo menos 1 no e 1 acao.
#
# uso: sh gen-powerhint.sh <ficheiro_saida> [adpf-config.json]
# ---------------------------------------------------------------------------

OUT=${1:-/data/adb/libperfmgr/powerhint.json}
ADPF=${2:-/data/adb/modules/libperfmgr-hyperos/common/adpf-config.json}

# bases sobrepostas nos testes
CPU_BASE=${CPU_BASE:-/sys/devices/system/cpu}
STUNE_BASE=${STUNE_BASE:-/dev/stune}

TMPD=$(mktemp -d 2>/dev/null)
[ -n "$TMPD" ] || TMPD=/data/local/tmp/perfmgr-gen.$$
mkdir -p "$TMPD" 2>/dev/null
NODE_F=$TMPD/nodes
ACT_F=$TMPD/actions
: >"$NODE_F"
: >"$ACT_F"

# ------------------------------- utilitarios --------------------------------
dedupe() {
    # remove repetidos e espacos a mais (valores duplicados quebram o parse do HintManager)
    echo "$1" | tr ' ' '\n' | grep -E '^[0-9]+$' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/ *$//'
}

jarr() {
    # transforma "a b c" em ["a","b","c"]
    printf '['
    first=1
    for v in $1; do
        if [ $first -eq 1 ]; then first=0; else printf ','; fi
        printf '"%s"' "$v"
    done
    printf ']'
}

writable() {
    # 0 se o ficheiro existe e o dono (root) tem permissao de escrita
    [ -e "$1" ] || return 1
    m=$(stat -c %a "$1" 2>/dev/null) || return 1
    m=$(printf '%03d' "$m" 2>/dev/null)
    case "${m%??}" in
    2 | 3 | 6 | 7) return 0 ;;
    *) return 1 ;;
    esac
}

add_node() {
    # $1 nome | $2 caminho | $3 valores (json array) | $4 extras (json, comeca por ',')
    grep -q "\"Name\": \"$1\"" "$NODE_F" 2>/dev/null && return 0
    printf '    {"Name": "%s", "Path": "%s", "Values": %s%s}\n' "$1" "$2" "$3" "$4" >>"$NODE_F"
}

add_action() {
    # $1 hint | $2 no | $3 valor | $4 duracao (ms)
    printf '    {"PowerHint": "%s", "Node": "%s", "Value": "%s", "Duration": %s}\n' \
        "$1" "$2" "$3" "$4" >>"$ACT_F"
}

max_ladder() {
    # valores descendentes para scaling_max_freq
    avail=$(cat "$1/scaling_available_frequencies" 2>/dev/null)
    max=$(cat "$1/cpuinfo_max_freq" 2>/dev/null)
    min=$(cat "$1/cpuinfo_min_freq" 2>/dev/null)
    if [ -n "$avail" ]; then
        echo "$avail" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -rn | awk 'NR==1 || (NR%2==1 && NR<=5)' | head -4
    else
        awk -v a="${max:-2000000}" -v b="${min:-500000}" 'BEGIN{
            print a
            split(sprintf("%d %d %d", int(a*0.85/1000)*1000, int(a*0.70/1000)*1000, int(a*0.55/1000)*1000), v, " ")
            for (i=1;i<=3;i++) if (v[i] > b) print v[i]
        }'
    fi
}

min_ladder() {
    # valores ascendentes para scaling_min_freq (0 = sem boost)
    avail=$(cat "$1/scaling_available_frequencies" 2>/dev/null)
    max=$(cat "$1/cpuinfo_max_freq" 2>/dev/null)
    min=$(cat "$1/cpuinfo_min_freq" 2>/dev/null)
    if [ -n "$avail" ]; then
        echo "$avail" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -n | awk 'NR==1 || (NR%2==1 && NR<=5)' | head -4
    else
        awk -v a="${max:-2000000}" -v b="${min:-500000}" 'BEGIN{
            print b
            split(sprintf("%d %d %d", int(a*0.45/1000)*1000, int(a*0.65/1000)*1000, int(a*0.85/1000)*1000), v, " ")
            for (i=1;i<=3;i++) if (v[i] > b && v[i] < a) print v[i]
        }'
    fi
}

# --------------------------- detecao: clusters CPU --------------------------
detect_cpu() {
    for pol in "$CPU_BASE"/cpufreq/policy*; do
        [ -d "$pol" ] || continue
        idx=${pol##*/policy}
        case "$idx" in
        '' | *[!0-9]*) idx=0 ;;
        esac

        fmax=$pol/scaling_max_freq
        fmin=$pol/scaling_min_freq

        if writable "$fmax"; then
            vals=$(dedupe "$(max_ladder "$pol" | tr '\n' ' ')")
            [ -n "$vals" ] && add_node "CPUPolicy${idx}MaxFreq" "$fmax" \
                "$(jarr "$vals")" ', "DefaultIndex": 0, "ResetOnInit": true, "WriteOnly": true'
        fi

        if writable "$fmin"; then
            vals=$(dedupe "$(min_ladder "$pol" | tr '\n' ' ')")
            [ -n "$vals" ] && {
                add_node "CPUPolicy${idx}MinFreq" "$fmin" \
                    "$(jarr "$vals")" ', "DefaultIndex": 0, "ResetOnInit": true, "WriteOnly": true'
                # boost de arranque/interacao: 3.o valor da escada (se existir)
                boost=$(echo "$vals" | tr ' ' '\n' | grep -E '^[0-9]+$' | sed -n '3p')
                [ -n "$boost" ] || boost=$(echo "$vals" | tr ' ' '\n' | grep -E '^[0-9]+$' | tail -n 1)
                CPU_BOOST_NODES="$CPU_BOOST_NODES CPUPolicy${idx}MinFreq=$boost"
            }
        fi
    done
}

# ------------------------------- detecao: GPU -------------------------------
detect_gpu() {
    GPU_DIR=""
    # Adreno (Qualcomm)
    for d in /sys/class/kgsl/kgsl-3d0; do
        [ -d "$d/devfreq" ] && GPU_DIR=$d/devfreq && break
    done
    # Mali / genérico devfreq
    if [ -z "$GPU_DIR" ]; then
        for d in /sys/class/devfreq/*; do
            [ -d "$d" ] || continue
            case "$d" in *gpu* | *kgsl* | *mali*)
                if [ -f "$d/min_freq" ] || [ -f "$d/max_freq" ]; then GPU_DIR=$d && break; fi
                ;;
            esac
        done
    fi
    # Mali com nos "hint_"
    [ -z "$GPU_DIR" ] && for d in /sys/devices/platform/*.mali*; do
        if [ -f "$d/hint_min_freq" ] || [ -f "$d/hint_max_freq" ]; then GPU_DIR=$d && break; fi
    done

    [ -n "$GPU_DIR" ] || return 0

    gmin=$GPU_DIR/min_freq
    gmax=$GPU_DIR/max_freq
    [ -f "$gmin" ] || gmin=$GPU_DIR/hint_min_freq
    [ -f "$gmax" ] || gmax=$GPU_DIR/hint_max_freq

    if writable "$gmin"; then
        avail=$(cat "$GPU_DIR/available_frequencies" 2>/dev/null)
        if [ -n "$avail" ]; then
            vals=$(echo "$avail" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -n | awk 'NR==1 || (NR%2==1 && NR<=5)' | head -4 | tr '\n' ' ')
        else
            cur=$(cat "$gmin" 2>/dev/null)
            hi=$(cat "$gmax" 2>/dev/null)
            vals=$(dedupe "${cur:-0} ${hi:-0}")
        fi
        vals=$(dedupe "$vals")
        [ -n "$vals" ] && {
            add_node "GPUMinFreq" "$gmin" "$(jarr "$vals")" \
                ', "DefaultIndex": 0, "ResetOnInit": true, "WriteOnly": true' 
            GPU_BOOST=$(echo "$vals" | tr ' ' '\n' | grep -E '^[0-9]+$' | sed -n '2p')
            [ -n "$GPU_BOOST" ] || GPU_BOOST=$(echo "$vals" | tr ' ' '\n' | grep -E '^[0-9]+$' | head -n 1)
        }
    fi
    # GpuSysfsPath e usado pelo GpuCapacityNode (ADPF GPU boost) e so faz sentido
    # no layout Mali ("hint_min_freq"); em Adreno deixamos vazio e o ADPF ignora o boost de GPU
    case "$gmin" in
    *hint_min_freq) GPU_SYSFS_DIR=$GPU_DIR ;;
    *) GPU_SYSFS_DIR="" ;;
    esac
}

# --------------------------- detecao: schedtune -----------------------------
detect_stune() {
    for g in top-app foreground; do
        f=$STUNE_BASE/$g/schedtune.boost
        if writable "$f"; then
            add_node "StuneBoost" "$f" '["0","10","20","30","50"]' \
                ', "DefaultIndex": 0, "ResetOnInit": true' 
            STUNE_NODE=StuneBoost
            return 0
        fi
    done
    STUNE_NODE=""
}

# --------------------------------- acoes ------------------------------------
build_actions() {
    if [ -n "$CPU_BOOST_NODES" ]; then
        first_node=""
        first_val=""
        for pair in $CPU_BOOST_NODES; do
            node=${pair%%=*}
            val=${pair##*=}
            if [ -n "$val" ]; then
                # LAUNCH em 1200ms (tempo ideal para abrir app sem drenar bateria)
                add_action LAUNCH "$node" "$val" 1200
                [ -z "$first_node" ] && { first_node="$node"; first_val="$val"; }
            fi
        done
        # INTERACTION rapido de toque (250ms)
        if [ -n "$first_node" ] && [ -n "$first_val" ]; then
            add_action INTERACTION "$first_node" "$first_val" 250
        fi
    fi
    [ -n "$STUNE_NODE" ] && {
        add_action LAUNCH "$STUNE_NODE" 50 1200
        add_action INTERACTION "$STUNE_NODE" 30 250
    }

    # garantir pelo menos uma acao
    if [ ! -s "$ACT_F" ]; then
        add_action LAUNCH PerfMgrNoOp 1 1
    fi
}

# ---------------------------- no de recurso (fallback) ----------------------
add_fallback_node() {
    # usado quando o kernel nao expoe nenhum no aproveitavel:
    # um no do tipo "Property" e sempre valido para o HintManager
    add_node "PerfMgrNoOp" "vendor.perfmgr.noop" '["0","1"]' \
        ', "Type": "Property", "DefaultIndex": 0' 
}

# ---------------------------------- main ------------------------------------
CPU_BOOST_NODES=""
GPU_BOOST=""
GPU_SYSFS_DIR=""
STUNE_NODE=""

detect_cpu
detect_gpu
detect_stune

if [ ! -s "$NODE_F" ]; then
    add_fallback_node
fi
build_actions

# nunca devolve vazio: se algo falhou, usa um conjunto minimo garantido
[ -s "$NODE_F" ] || add_node "PerfMgrNoOp" "vendor.perfmgr.noop" '["0","1"]' ', "Type": "Property", "DefaultIndex": 0' 
[ -s "$ACT_F" ] || add_action LAUNCH PerfMgrNoOp 1 1

mkdir -p "$(dirname "$OUT")" 2>/dev/null
{
    printf '{\n'
    printf '  "Nodes": [\n'
    awk '{ printf "%s%s", sep, $0; sep=",\n" } END { if (NR) printf "\n" }' "$NODE_F"
    printf '  ],\n'
    printf '  "Actions": [\n'
    awk '{ printf "%s%s", sep, $0; sep=",\n" } END { if (NR) printf "\n" }' "$ACT_F"
    printf '  ],\n'
    if [ -n "$GPU_SYSFS_DIR" ]; then
        printf '  "GpuSysfsPath": "%s",\n' "$GPU_SYSFS_DIR"
    fi
    if [ -f "$ADPF" ]; then
        printf '  "AdpfConfig": '
        cat "$ADPF"
    fi
    printf '}\n'
} >"$OUT"

# validacao minima
if ! grep -q '"Nodes"' "$OUT" 2>/dev/null || ! grep -q '"Actions"' "$OUT" 2>/dev/null; then
    printf '{\n  "Nodes": [\n    {"Name": "PerfMgrNoOp", "Path": "vendor.perfmgr.noop", "Values": ["0","1"], "Type": "Property", "DefaultIndex": 0}\n  ],\n  "Actions": [\n    {"PowerHint": "LAUNCH", "Node": "PerfMgrNoOp", "Value": "1", "Duration": 1}\n  ]\n}\n' >"$OUT"
fi

rm -rf "$TMPD" 2>/dev/null
exit 0
