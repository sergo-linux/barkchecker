#!/bin/bash

REPO_USER="sergo-linux"
REPO_NAME="barkchecker"

say() {
    local ru="$1"
    local en="$2"

    if [[ "$LANGUAGE" == "ru" ]]; then
        echo "$ru"
    else
        echo "$en"
    fi
}

spinner_run() {
    local pid=$1
    local message_ru="$2"
    local message_en="$3"
    local spin='|/-\'
    local i=0

    if [[ "$LANGUAGE" == "ru" ]]; then
        printf "%s " "$message_ru"
    else
        printf "%s " "$message_en"
    fi

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % 4 ))
        printf "\r%s %c" "${LANGUAGE:-ru}" ""
        if [[ "$LANGUAGE" == "ru" ]]; then
            printf "\r%s %c" "$message_ru" "${spin:$i:1}"
        else
            printf "\r%s %c" "$message_en" "${spin:$i:1}"
        fi
        sleep 0.1
    done

    if [[ "$LANGUAGE" == "ru" ]]; then
        printf "\r%s ✓\n" "$message_ru"
    else
        printf "\r%s ✓\n" "$message_en"
    fi
}

check_tool() {
    command -v "$1" >/dev/null 2>&1
}

choose_language() {
    echo ""
    echo "Choose language / Выберите язык:"
    echo "1) Русский"
    echo "2) English"
    echo ""

    while true; do
        read -r -p "Enter 1 or 2: " lang_choice
        case "$lang_choice" in
            1)
                LANGUAGE="ru"
                break
                ;;
            2)
                LANGUAGE="en"
                break
                ;;
            *)
                echo "Invalid choice / Неверный выбор"
                ;;
        esac
    done
}

choose_channel() {
    echo ""

    if [[ "$LANGUAGE" == "ru" ]]; then
        echo "Выберите канал:"
        echo "1) stable"
        echo "2) beta"
        echo ""
        while true; do
            read -r -p "Введите 1 или 2: " channel_choice
            case "$channel_choice" in
                1)
                    CHANNEL="stable"
                    BRANCH="main"
                    break
                    ;;
                2)
                    CHANNEL="beta"
                    BRANCH="beta"
                    break
                    ;;
                *)
                    echo "Неверный выбор"
                    ;;
            esac
        done
    else
        echo "Choose channel:"
        echo "1) stable"
        echo "2) beta"
        echo ""
        while true; do
            read -r -p "Enter 1 or 2: " channel_choice
            case "$channel_choice" in
                1)
                    CHANNEL="stable"
                    BRANCH="main"
                    break
                    ;;
                2)
                    CHANNEL="beta"
                    BRANCH="beta"
                    break
                    ;;
                *)
                    echo "Invalid choice"
                    ;;
            esac
        done
    fi
}

ask_installed_action() {
    echo ""

    if [[ "$LANGUAGE" == "ru" ]]; then
        echo "Bark Checker уже установлен."
        echo "1) Переустановить"
        echo "2) Удалить"
        echo "3) Выйти"
        echo ""
        while true; do
            read -r -p "Введите 1, 2 или 3: " action_choice
            case "$action_choice" in
                1)
                    INSTALL_ACTION="reinstall"
                    break
                    ;;
                2)
                    INSTALL_ACTION="remove"
                    break
                    ;;
                3)
                    INSTALL_ACTION="exit"
                    break
                    ;;
                *)
                    echo "Неверный выбор"
                    ;;
            esac
        done
    else
        echo "Bark Checker is already installed."
        echo "1) Reinstall"
        echo "2) Remove"
        echo "3) Exit"
        echo ""
        while true; do
            read -r -p "Enter 1, 2 or 3: " action_choice
            case "$action_choice" in
                1)
                    INSTALL_ACTION="reinstall"
                    break
                    ;;
                2)
                    INSTALL_ACTION="remove"
                    break
                    ;;
                3)
                    INSTALL_ACTION="exit"
                    break
                    ;;
                *)
                    echo "Invalid choice"
                    ;;
            esac
        done
    fi
}

require_sudo() {
    if [[ "$EUID" -ne 0 ]]; then
        say "Требуются права sudo..." "Sudo privileges required..."
        sudo -v || exit 1
    fi
}

check_remote() {
    local url="$1"

    if check_tool curl; then
        curl -Is "$url" >/dev/null 2>&1
        return $?
    elif check_tool wget; then
        wget --spider -q "$url"
        return $?
    else
        return 127
    fi
}

download_with_progress() {
    local url="$1"
    local output="$2"

    if check_tool curl; then
        curl -fL --progress-bar "$url" -o "$output"
        return $?
    elif check_tool wget; then
        wget --show-progress "$url" -O "$output"
        return $?
    else
        return 127
    fi
}

download_or_fail() {
    local url="$1"
    local output="$2"
    local fail_ru="$3"
    local fail_en="$4"

    if ! download_with_progress "$url" "$output"; then
        if [[ "$LANGUAGE" == "ru" ]]; then
            echo "Ошибка: $fail_ru"
        else
            echo "Error: $fail_en"
        fi
        return 1
    fi

    if [[ ! -s "$output" ]]; then
        if [[ "$LANGUAGE" == "ru" ]]; then
            echo "Ошибка: файл скачан пустым"
        else
            echo "Error: downloaded file is empty"
        fi
        return 1
    fi

    return 0
}

remove_installation() {
    local install_path="$1"
    local config_dir="$2"

    require_sudo

    if [[ -f "$install_path" ]]; then
        sudo rm -f "$install_path"
    fi

    if [[ -d "$config_dir" ]]; then
        echo ""
        if [[ "$LANGUAGE" == "ru" ]]; then
            read -r -p "Удалить также ~/.barkchecker со всеми логами, базой и карантином? (д/н): " remove_config
            case "$remove_config" in
                д|Д)
                    rm -rf "$config_dir"
                    ;;
            esac
        else
            read -r -p "Remove ~/.barkchecker with all logs, database and quarantine too? (y/n): " remove_config
            case "$remove_config" in
                y|Y)
                    rm -rf "$config_dir"
                    ;;
            esac
        fi
    fi

    say "Удаление завершено." "Removal complete."
    exit 0
}

prepare_urls() {
    PROGRAM_URL="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/barkchecker"
    SH_DB_URL="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/db/sh.db"
    BUNDLE_DB_URL="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH/db/bundle.db"
}

main() {
    INSTALL_PATH="/usr/local/bin/barkchecker"
    CONFIG_DIR="$HOME/.barkchecker"
    DB_DIR="$CONFIG_DIR/db"
    QUARANTINE_DIR="$CONFIG_DIR/.quarantine"
    SETTINGS_FILE="$CONFIG_DIR/settings.conf"
    LOG_FILE="$CONFIG_DIR/logs.log"

    TMP_DIR="/tmp/barkchecker_install"
    TMP_PROGRAM="$TMP_DIR/barkchecker"
    TMP_SH_DB="$TMP_DIR/sh.db"
    TMP_BUNDLE_DB="$TMP_DIR/bundle.db"

    if ! check_tool curl && ! check_tool wget; then
        echo "Error: curl or wget is required"
        exit 1
    fi

    choose_language

    if [[ -x "$INSTALL_PATH" ]] || command -v barkchecker >/dev/null 2>&1; then
        ask_installed_action

        case "$INSTALL_ACTION" in
            reinstall)
                ;;
            remove)
                remove_installation "$INSTALL_PATH" "$CONFIG_DIR"
                ;;
            exit)
                say "Выход." "Exit."
                exit 0
                ;;
        esac
    fi

    choose_channel
    prepare_urls

    mkdir -p "$TMP_DIR"

    (
        check_remote "$PROGRAM_URL"
    ) &
    spinner_run $! "Проверка доступа к GitHub..." "Checking GitHub access..."

    if ! check_remote "$PROGRAM_URL"; then
        if [[ "$CHANNEL" == "beta" ]]; then
            say "Beta канал недоступен, переключаемся на stable..." "Beta channel unavailable, falling back to stable..."

            CHANNEL="stable"
            BRANCH="main"
            prepare_urls

            (
                check_remote "$PROGRAM_URL"
            ) &
            spinner_run $! "Повторная проверка stable..." "Re-checking stable..."

            if ! check_remote "$PROGRAM_URL"; then
                say "Ошибка: stable тоже недоступен" "Error: stable is also unavailable"
                exit 1
            fi
        else
            say "Ошибка: нет доступа к GitHub или файлы недоступны" "Error: cannot access GitHub or files are unavailable"
            exit 1
        fi
    fi

    echo ""
    say "Скачивание Bark Checker..." "Downloading Bark Checker..."
    download_or_fail "$PROGRAM_URL" "$TMP_PROGRAM" "не удалось скачать barkchecker" "failed to download barkchecker" || exit 1

    echo ""
    say "Скачивание базы sh.db..." "Downloading sh.db..."
    download_or_fail "$SH_DB_URL" "$TMP_SH_DB" "не удалось скачать sh.db" "failed to download sh.db" || exit 1

    echo ""
    say "Скачивание базы bundle.db..." "Downloading bundle.db..."
    download_or_fail "$BUNDLE_DB_URL" "$TMP_BUNDLE_DB" "не удалось скачать bundle.db" "failed to download bundle.db" || exit 1

    chmod +x "$TMP_PROGRAM"
    require_sudo

    (
        mkdir -p "$CONFIG_DIR" "$DB_DIR" "$QUARANTINE_DIR"
        touch "$LOG_FILE"
    ) &
    spinner_run $! "Подготовка каталогов..." "Preparing directories..."

    sudo mv "$TMP_PROGRAM" "$INSTALL_PATH" || {
        say "Ошибка: не удалось переместить barkchecker в /usr/local/bin" "Error: failed to move barkchecker to /usr/local/bin"
        exit 1
    }

    sudo chmod +x "$INSTALL_PATH" || {
        say "Ошибка: не удалось выдать права на выполнение" "Error: failed to set executable permissions"
        exit 1
    }

    cp "$TMP_SH_DB" "$DB_DIR/sh.db" || {
        say "Ошибка: не удалось установить sh.db" "Error: failed to install sh.db"
        exit 1
    }

    cp "$TMP_BUNDLE_DB" "$DB_DIR/bundle.db" || {
        say "Ошибка: не удалось установить bundle.db" "Error: failed to install bundle.db"
        exit 1
    }

    cat > "$SETTINGS_FILE" <<EOF
LANGUAGE="$LANGUAGE"
CHANNEL="$CHANNEL"
FIRST_RUN="1"
EOF

    rm -f "$TMP_SH_DB" "$TMP_BUNDLE_DB"
    rm -f "$TMP_PROGRAM"
    rmdir "$TMP_DIR" 2>/dev/null || true

    echo ""
    say "Установка завершена." "Installation complete."
    say "Язык: $LANGUAGE" "Language: $LANGUAGE"
    say "Канал: $CHANNEL" "Channel: $CHANNEL"
    say "Путь утилиты: $INSTALL_PATH" "Program path: $INSTALL_PATH"
    say "Папка конфигурации: $CONFIG_DIR" "Config directory: $CONFIG_DIR"
    echo ""
    say "Запуск: barkchecker" "Run: barkchecker"
}

main