# OS Practice 2 — Variant B

Практическая работа по Bash, Python и анализу системных вызовов через `strace`.

## Задание

1. `report.sh`: аргументы — каталог и уровень `ERROR`/`WARN`; вывод — таблица «модуль → число сообщений» по убыванию. При отсутствии аргументов — справка и код возврата `1`.
2. Добавить режим `--top N` и проверку существования каталога.
3. `hello.py`: читает файл и выводит его размер. Снять `strace -f -o trace.txt python3 hello.py test.txt`. В README указать общее число системных вызовов, число вызовов, относящихся к чтению файла, и объяснить накладные расходы интерпретатора.
4. Сравнить число системных вызовов `cat` и `python3 hello.py` на одном файле и сделать вывод.

## Структура проекта

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

После запуска анализа появляются:

```text
trace.txt
cat_trace.txt
python_summary.txt
cat_summary.txt
analysis_results.txt
```

## 1. report.sh

Тестовые логи имеют формат:

```text
DATE MODULE LEVEL MESSAGE
```

Скрипт ищет модуль как слово непосредственно перед `ERROR` или `WARN`.

Сделать скрипт исполняемым:

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

Для приложенных тестовых логов команда:

```bash
./report.sh logs ERROR
```

даёт модули в порядке убывания количества сообщений: `auth`, `database`, `api`.

## 2. hello.py

Запуск:

```bash
python3 hello.py test.txt
```

Для приложенного `test.txt` результат:

```text
Размер файла: 24 байт
```

Программа действительно открывает файл в бинарном режиме, читает его содержимое и считает количество прочитанных байт.

## 3. Анализ системных вызовов Python

Основная команда из задания:

```bash
strace -f -o trace.txt python3 hello.py test.txt
```

Для точного подсчёта общего числа системных вызовов дополнительно используется:

```bash
strace -f -c -o python_summary.txt python3 hello.py test.txt
```

`run_analysis.sh` выполняет обе команды автоматически и обновляет блок результатов ниже.

<!-- STRACE_RESULTS_START -->
### Реальные результаты strace

Результаты ещё не сгенерированы. Запустите:

```bash
chmod +x run_analysis.sh
./run_analysis.sh
```

После этого этот блок README автоматически заполнится реальными числами с Linux-машины.
<!-- STRACE_RESULTS_END -->

### Какие вызовы относятся к чтению файла

Сначала файл открывается через `openat`/аналогичный вызов. Ядро возвращает файловый дескриптор. Затем Python выполняет операции с этим дескриптором, например `read`, `newfstatat`/`fstat`, иногда `lseek`, после чего выполняется `close`.

Скрипт `run_analysis.sh` автоматически находит открытие именно исследуемого файла и считает операции с его файловым дескриптором до закрытия.

### Почему остальных вызовов намного больше

Перед выполнением кода `hello.py` Python должен запустить интерпретатор. Во время запуска он:

- загружает динамические библиотеки;
- ищет и загружает Python-модули;
- проверяет файлы и каталоги;
- выделяет и отображает память;
- инициализирует стандартные потоки и среду выполнения.

Поэтому в `trace.txt` появляется много `openat`, `newfstatat`, `mmap`, `mprotect`, `brk`, `read`, `close` и других вызовов, не связанных напрямую с чтением `test.txt`. Это накладные расходы интерпретатора.

## 4. Сравнение cat и Python

Для сравнения используется один и тот же файл:

```bash
strace -f -c -o cat_summary.txt cat test.txt
strace -f -c -o python_summary.txt python3 hello.py test.txt
```

Полные traces:

```bash
strace -f -o cat_trace.txt cat test.txt
strace -f -o trace.txt python3 hello.py test.txt
```

### Вывод

`cat` обычно выполняет заметно меньше системных вызовов, потому что это небольшая скомпилированная программа, которая после запуска почти сразу открывает и читает файл.

`python3 hello.py` сначала запускает и инициализирует интерпретатор Python, загружает библиотеки и выполняет подготовительные операции, а затем выполняет код программы. Поэтому накладные расходы Python по числу системных вызовов значительно выше.

## Быстрый запуск всей практики

На Ubuntu/Debian при необходимости установить `strace`:

```bash
sudo apt update
sudo apt install strace
```

Затем:

```bash
chmod +x report.sh run_analysis.sh

./report.sh logs ERROR
./report.sh --top 2 logs WARN

python3 hello.py test.txt
./run_analysis.sh
```

После `run_analysis.sh` полные результаты находятся в `trace.txt`, `cat_trace.txt`, `python_summary.txt`, `cat_summary.txt` и `analysis_results.txt`.
