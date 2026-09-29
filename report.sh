#!/usr/bin/env bash

set -u

show_help() {
    cat <<'EOF'
Использование:
  ./report.sh <каталог> <ERROR|WARN>
  ./report.sh --top N <каталог> <ERROR|WARN>

Примеры:
  ./report.sh logs ERROR
  ./report.sh logs WARN
  ./report.sh --top 2 logs ERROR
EOF
}

if [ "$#" -eq 0 ]; then
    show_help
    exit 1
fi

TOP=""
DIRECTORY=""
LEVEL=""

if [ "$1" = "--top" ]; then
    if [ "$#" -ne 4 ]; then
        show_help
        exit 1
    fi

    TOP="$2"
    DIRECTORY="$3"
    LEVEL="$4"

    if ! [[ "$TOP" =~ ^[1-9][0-9]*$ ]]; then
        echo "Ошибка: N после --top должно быть положительным целым числом." >&2
        exit 1
    fi
else
    if [ "$#" -ne 2 ]; then
        show_help
        exit 1
    fi

    DIRECTORY="$1"
    LEVEL="$2"
fi

if [ ! -d "$DIRECTORY" ]; then
    echo "Ошибка: каталог '$DIRECTORY' не существует." >&2
    exit 1
fi

if [ "$LEVEL" != "ERROR" ] && [ "$LEVEL" != "WARN" ]; then
    echo "Ошибка: уровень должен быть ERROR или WARN." >&2
    exit 1
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

find "$DIRECTORY" -type f -exec cat {} + 2>/dev/null |
awk -v wanted_level="$LEVEL" '
{
    for (i = 1; i <= NF; i++) {
        if ($i == wanted_level && i > 1) {
            module = $(i - 1)
            gsub(/^[[:punct:]]+|[[:punct:]]+$/, "", module)
            if (module != "") {
                count[module]++
            }
            break
        }
    }
}
END {
    for (module in count) {
        print module, count[module]
    }
}
' |
sort -k2,2nr -k1,1 > "$TMP_FILE"

printf "%-20s %s\n" "МОДУЛЬ" "КОЛИЧЕСТВО"
printf "%-20s %s\n" "--------------------" "----------"

if [ -n "$TOP" ]; then
    head -n "$TOP" "$TMP_FILE" | awk '{printf "%-20s %s\n", $1, $2}'
else
    awk '{printf "%-20s %s\n", $1, $2}' "$TMP_FILE"
fi
