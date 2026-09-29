# OS Practice 2 — Variant B

Практическая работа по Bash, Python и анализу системных вызовов через `strace`.

## Задание

1. `report.sh`: аргументы — каталог и уровень `ERROR`/`WARN`; вывод — таблица «модуль → число сообщений» по убыванию. При отсутствии аргументов — справка и код возврата `1`.
2. Добавить режим `--top N` и проверку существования каталога.
3. `hello.py`: читает файл и выводит его размер. Снять `strace -f -o trace.txt python3 hello.py test.txt`. Объяснить количество системных вызовов и накладные расходы интерпретатора.
4. Сравнить число системных вызовов `cat` и `python3 hello.py` на одном файле.

## Структура

```text
.
├── report.sh
├── hello.py
├── run_analysis.sh
├── test.txt
├── logs/
│   ├── app.log
│   └── server.log
└── README.md
```

После запуска `./run_analysis.sh` дополнительно появятся:

```text
trace.txt
cat_trace.txt
python_summary.txt
cat_summary.txt
analysis_results.txt
```

## 1. report.sh

Формат тестовых логов в папке `logs/`:

```text
DATE MODULE LEVEL MESSAGE
```

Скрипт также ищет модуль как слово непосредственно перед `ERROR` или `WARN`, поэтому он не привязан к точному количеству полей перед уровнем.

Сделать файл исполняемым:

```bash
chmod +x report.sh
```

Проверка без аргументов:

```bash
./report.sh
echo $?
```

Ожидаемый код возврата:

```text
1
```

Обычный запуск:

```bash
./report.sh logs ERROR
./report.sh logs WARN
```

Режим `--top N`:

```bash
./report.sh --top 2 logs ERROR
```

Проверка несуществующего каталога:

```bash
./report.sh no_such_directory ERROR
```

## 2. hello.py

Запуск:

```bash
python3 hello.py test.txt
```

Программа действительно открывает и читает файл в бинарном режиме, после чего выводит количество прочитанных байт.

## 3. strace для Python

На Ubuntu/Debian при необходимости:

```bash
sudo apt update
sudo apt install strace
```

Команда из задания:

```bash
strace -f -o trace.txt python3 hello.py test.txt
```

Количество строк trace:

```bash
wc -l trace.txt
```

Для более точной сводки по числу системных вызовов:

```bash
strace -f -c -o python_summary.txt python3 hello.py test.txt
cat python_summary.txt
```

Число системных вызовов зависит от версии Linux, Python, glibc и окружения, поэтому в отчёте нужно использовать результат с машины, где выполнялась практика.

### Какие вызовы относятся к чтению нашего файла

Сначала можно найти открытие файла:

```bash
grep "test.txt" trace.txt
```

Обычно среди относящихся к нашему файлу вызовов будут:

- `openat(..., "test.txt", ...)` — открыть файл;
- `read(...)` — прочитать содержимое;
- `newfstatat(...)` или похожий вызов — получить информацию о файле;
- `close(...)` — закрыть файловый дескриптор.

Важно считать только вызовы для файлового дескриптора, который был возвращён при открытии именно `test.txt`.

### Почему остальных вызовов намного больше

Перед выполнением нескольких строк из `hello.py` Python должен запустить интерпретатор. Во время запуска он:

- загружает динамические библиотеки;
- ищет и загружает модули;
- проверяет файлы и каталоги;
- выделяет и отображает память;
- инициализирует стандартный ввод/вывод и окружение.

Поэтому в trace встречается много `openat`, `newfstatat`, `mmap`, `mprotect`, `brk`, `read`, `close` и других системных вызовов, не связанных напрямую с чтением `test.txt`. Это и есть накладные расходы интерпретатора.

## 4. Сравнение cat и Python

Для корректного сравнения используется один и тот же файл `test.txt`:

```bash
strace -f -c -o cat_summary.txt cat test.txt
strace -f -c -o python_summary.txt python3 hello.py test.txt

cat cat_summary.txt
cat python_summary.txt
```

Также можно сохранить полные traces:

```bash
strace -f -o cat_trace.txt cat test.txt
strace -f -o trace.txt python3 hello.py test.txt
```

### Вывод

`cat` обычно выполняет заметно меньше системных вызовов, потому что это небольшая скомпилированная программа, которая после запуска практически сразу открывает и читает файл.

`python3 hello.py` сначала запускает и инициализирует интерпретатор Python, загружает библиотеки и выполняет подготовительные операции, и только потом выполняет код `hello.py`. Поэтому у Python накладные расходы по числу системных вызовов значительно выше.

## Автоматический запуск анализа

Скрипт:

```bash
chmod +x run_analysis.sh
./run_analysis.sh
```

создаёт полные trace-файлы и статистику для `cat` и Python. После этого реальные результаты можно посмотреть в:

```bash
cat analysis_results.txt
cat python_summary.txt
cat cat_summary.txt
```

Если эти runtime-файлы нужно приложить к сдаче, после запуска добавьте их в Git:

```bash
git add trace.txt cat_trace.txt python_summary.txt cat_summary.txt analysis_results.txt
git commit -m "Add strace results"
git push
```
