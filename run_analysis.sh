#!/usr/bin/env bash

set -euo pipefail

FILE="${1:-test.txt}"

if ! command -v strace >/dev/null 2>&1; then
    echo "Ошибка: strace не установлен." >&2
    echo "Ubuntu/Debian: sudo apt update && sudo apt install strace" >&2
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo "Ошибка: файл '$FILE' не найден." >&2
    exit 1
fi

echo "1) Снимаем полный trace Python..."
strace -f -o trace.txt python3 hello.py "$FILE"

echo "2) Снимаем полный trace cat..."
strace -f -o cat_trace.txt cat "$FILE" >/dev/null

echo "3) Получаем сводную статистику Python..."
strace -f -c -o python_summary.txt python3 hello.py "$FILE" >/dev/null

echo "4) Получаем сводную статистику cat..."
strace -f -c -o cat_summary.txt cat "$FILE" >/dev/null

python_trace_lines="$(wc -l < trace.txt | tr -d ' ')"
cat_trace_lines="$(wc -l < cat_trace.txt | tr -d ' ')"

python_total="$(awk '$NF == "total" {print $(NF-1)}' python_summary.txt | tail -n 1)"
cat_total="$(awk '$NF == "total" {print $(NF-1)}' cat_summary.txt | tail -n 1)"

{
    echo "Файл: $FILE"
    echo
    echo "Полный trace (число строк):"
    echo "python3 hello.py: $python_trace_lines"
    echo "cat:              $cat_trace_lines"
    echo
    echo "Всего системных вызовов по strace -c:"
    echo "python3 hello.py: ${python_total:-не удалось определить}"
    echo "cat:              ${cat_total:-не удалось определить}"
    echo
    echo "Открытие исследуемого файла в Python trace:"
    grep -F "\"$FILE\"" trace.txt || true
} > analysis_results.txt

echo
echo "Готово."
echo "Созданы:"
echo "  trace.txt"
echo "  cat_trace.txt"
echo "  python_summary.txt"
echo "  cat_summary.txt"
echo "  analysis_results.txt"
echo
cat analysis_results.txt
