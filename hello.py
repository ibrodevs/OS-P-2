#!/usr/bin/env python3

import sys


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Использование: {sys.argv[0]} <файл>", file=sys.stderr)
        return 1

    filename = sys.argv[1]

    try:
        with open(filename, "rb") as file:
            data = file.read()
    except FileNotFoundError:
        print(f"Ошибка: файл '{filename}' не найден.", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"Ошибка чтения файла '{filename}': {exc}", file=sys.stderr)
        return 1

    print(f"Размер файла: {len(data)} байт")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
