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

# В строке total формат strace -c имеет столбец calls в поле 4.
python_total="$(awk '$NF == "total" {print $4}' python_summary.txt | tail -n 1)"
cat_total="$(awk '$NF == "total" {print $4}' cat_summary.txt | tail -n 1)"

# Считаем вызовы, которые относятся непосредственно к исследуемому файлу:
# открытие файла + операции с полученным файловым дескриптором до close().
file_calls="$(
python3 - "$FILE" <<'PY'
import re
import sys

target = sys.argv[1]
tracked = {}
count = 0

line_re = re.compile(
    r"^\s*(?:(\d+)\s+)?([A-Za-z0-9_]+)\((.*)\)\s+=\s+(.+)$"
)
fd_syscalls = {
    "read", "pread64", "readv", "preadv", "preadv2",
    "lseek", "newfstatat", "fstat", "fstat64", "close"
}

with open("trace.txt", "r", encoding="utf-8", errors="replace") as trace:
    for line in trace:
        match = line_re.match(line)
        if not match:
            continue

        pid = match.group(1) or "main"
        syscall = match.group(2)
        args = match.group(3)
        result = match.group(4)

        if syscall in {"open", "openat", "openat2"} and f'"{target}"' in line:
            fd_match = re.match(r"(-?\d+)", result.strip())
            if fd_match and int(fd_match.group(1)) >= 0:
                fd = fd_match.group(1)
                tracked[(pid, fd)] = True
                count += 1
            continue

        first_arg = args.split(",", 1)[0].strip()
        key = (pid, first_arg)

        if key in tracked and syscall in fd_syscalls:
            count += 1
            if syscall == "close":
                del tracked[key]

print(count)
PY
)"

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
    echo "Вызовов, непосредственно связанных с файлом '$FILE': ${file_calls:-0}"
    echo "(open/openat + операции с его файловым дескриптором до close)"
    echo
    echo "Открытие исследуемого файла в Python trace:"
    grep -F "\"$FILE\"" trace.txt || true
} > analysis_results.txt

# Обновляем специальный блок результатов в README реальными числами.
python3 - "$FILE" "${python_total:-?}" "${cat_total:-?}" "${file_calls:-0}" <<'PY'
from pathlib import Path
import re
import sys

filename, python_total, cat_total, file_calls = sys.argv[1:]
readme_path = Path("README.md")

if readme_path.exists():
    text = readme_path.read_text(encoding="utf-8")
    start = "<!-- STRACE_RESULTS_START -->"
    end = "<!-- STRACE_RESULTS_END -->"

    block = f"""<!-- STRACE_RESULTS_START -->
### Реальные результаты strace

Результаты автоматически получены для файла `{filename}` на Linux-машине, где запускался `run_analysis.sh`.

| Программа | Всего системных вызовов |
|---|---:|
| `python3 hello.py {filename}` | {python_total} |
| `cat {filename}` | {cat_total} |

Для `python3 hello.py` непосредственно с исследуемым файлом связано **{file_calls} системных вызовов**. Здесь считаются открытие файла и операции с полученным файловым дескриптором до его закрытия.

Остальные вызовы — в основном накладные расходы запуска интерпретатора Python: загрузка динамических библиотек и модулей, проверки файлов, отображение памяти и инициализация среды выполнения.
<!-- STRACE_RESULTS_END -->"""

    pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), re.S)
    if pattern.search(text):
        text = pattern.sub(block, text)
        readme_path.write_text(text, encoding="utf-8")
PY

echo
echo "Готово."
echo "Созданы:"
echo "  trace.txt"
echo "  cat_trace.txt"
echo "  python_summary.txt"
echo "  cat_summary.txt"
echo "  analysis_results.txt"
echo "README.md обновлён реальными результатами."
echo
cat analysis_results.txt
