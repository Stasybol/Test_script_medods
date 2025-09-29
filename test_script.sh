#!/bin/bash

# Тестовое задание Анастасии Болотниковой

# Устанавливаем значение сервера по умолчанию
DEFAULT_SERVER="default_server"
SERVER=${1:-$DEFAULT_SERVER}

# Получаем текущую дату
DATE=$(date +"%d_%m_%Y")

# Имена файлов
FAILED_FILE="${SERVER}_${DATE}_failed.out"
RUNNING_FILE="${SERVER}_${DATE}_running.out"
REPORT_FILE="${SERVER}_${DATE}_report.out"
ARCHIVE_NAME="${SERVER}_${DATE}"
ARCHIVES_DIR="archives"

# URL файла с которым работаем
URL="https://raw.githubusercontent.com/GreatMedivack/files/master/list.out"

#1 Скачиваем файл
CONTENT=$(curl -s -L "$URL")

# Проверяем результат
if [ $? -eq 1 ]; then
    echo "Ошибка при скачивании файла!"
    exit
fi

#2 Создаем файлы с сервисами в статусе Error или CrashLoopBackOff
echo "$CONTENT" | awk -v failed_file="$FAILED_FILE" -v running_file="$RUNNING_FILE" '
NR==1 {
    next  # Пропускаем строку заголовка
}
{
    # NAME - первый столбец, STATUS - третий столбец
    name = $1
    status = $3

    if (name ~ /-[a-z0-9]{6,10}-[a-z0-9]{5,7}$/) {
        original_name = name
        # Удаляем часть после последнего дефиса, которая соответствует шаблону
        sub("-[a-z0-9]{6,10}-[a-z0-9]{5,7}$", "", name)
    }

    if (status == "Error" || status == "CrashLoopBackOff") {
	print name > failed_file
    } else if (status == "Running") {
	print name > running_file
    }
}'

# Получаем статистику
RUNNING_COUNT=$(wc -l < "$RUNNING_FILE" 2>/dev/null || echo "0")
FAILED_COUNT=$(wc -l < "$FAILED_FILE" 2>/dev/null || echo "0")
USERNAME=$(whoami)
CURRENT_DATE="$DATE"

#3 Запись в REPORT_FILE нужных строк 
cat > "$REPORT_FILE" << EOF
Количество работающих сервисов: $RUNNING_COUNT
Количество сервисов с ошибками: $FAILED_COUNT
Имя системного пользователя: $USERNAME
Дата: $CURRENT_DATE
EOF

# Устанавливаем права на чтение для всех
chmod 644 "$REPORT_FILE"

#4 Создаем папку архив
mkdir -p "$ARCHIVES_DIR"

# Проверяем, существует ли архив с таким именем
if [ ! -f "$ARCHIVES_DIR/$ARCHIVE_NAME.tar.gz" ]; then
    # Упаковываем файлы в архив
    tar -czf "$ARCHIVES_DIR/$ARCHIVE_NAME.tar.gz" \
        "$FAILED_FILE" \
        "$RUNNING_FILE" \
        "$REPORT_FILE"
fi

#5 Удаляем все файлы кроме папки archives
rm -f "${SERVER}_${DATE}"*.out

ARCHIVE_PATH="$ARCHIVES_DIR/${SERVER}_${DATE}.tar.gz"

#6 Выполняем проверку архива
if tar -tzf "$ARCHIVE_PATH" > /dev/null 2>&1; then
    echo "УСПЕХ: Конец работы"
else
    echo "ОШИБКА: Архив поврежден"
    exit 1
fi

