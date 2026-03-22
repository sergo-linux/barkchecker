#!/bin/bash

# GitHub repository info
REPO_USER="sergo-linux"
REPO_NAME="barkchecker"

# Resolve real user and home directory even when running under sudo
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="${SUDO_USER:+$(eval echo "~$SUDO_USER")}"
REAL_HOME="${REAL_HOME:-$HOME}"

# Print a message in the selected language (ru/en)
say() {
    local ru="$1"
    local en="$2"
    if [[ "$LANGUAGE" == "ru" ]]; then
        echo "$ru"
    else
        echo "$en"
    fi
}

# Print an error message to stderr in the selected language
say_err() {
    local ru="$1"
    local en="$2"
    if [[ "$LANGUAGE" == "ru" ]]; then
        echo "Ошибка: $ru" >&2
    else
        echo "Error: $en" >&2
    fi
}

# Run a background command and show a spinner while it runs.
# Usage: spinner_run <function_name> <msg_ru> <msg_en>
# Returns the exit code of the background command.
spinner_run() {
    local cmd_func="$1"
    local message_ru="$2"
    local message_en="$3"
    local spin='|/-\'
    local i=0

    # Launch the command in the background
    "$cmd_func" &
    local pid=$!

    if [[ "$LANGUAGE" == "ru" ]]; then
        printf "%s " "$message_ru"
    else
        printf "%s " "$message_en"
    fi

    # Animate until the process exits
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % 4 ))
        if [[ "$LANGUAGE" == "ru" ]]; then
            printf "\r%s %c" "$message_ru" "${spin:$i:1}"
        else
            printf "\r%s %c" "$message_en" "${spin:$i:1}"
        fi
        sleep 0.1
    done

    # Collect exit code and print final status
    wait "$pid"
    local result=$?
    if [[ "$LANGUAGE" == "ru" ]]; then
        printf "\r%s done\n" "$message_ru"
    else
        printf "\r%s done\n" "$message_en"
    fi

    return $result
}

# Check whether a CLI tool is available on PATH
check_tool() {
    command -v "$1" >/dev/null 2>&1
}

# Prompt the user to pick a UI language (sets global $LANGUAGE)
choose_language() {
    echo ""
    echo "Choose language / Выберите язык:"
    echo "1) Русский"
    echo "2) English"
    echo ""
    while true; do
        read -r -p "Enter 1 or 2: " lang_choice
        case "$lang_choice" in
            1) LANGUAGE="ru"; break ;;
            2) LANGUAGE="en"; break ;;
            *) echo "Invalid choice / Неверный выбор" ;;
        esac
    done
}

# Prompt the user to pick stable or beta channel (sets $CHANNEL and $BRANCH)
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
                1) CHANNEL="stable"; BRANCH="main"; break ;;
                2) CHANNEL="beta";   BRANCH="beta"; break ;;
                *) echo "Неверный выбор" ;;
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
                1) CHANNEL="stable"; BRANCH="main"; break ;;
                2) CHANNEL="beta";   BRANCH="beta"; break ;;
                *) echo "Invalid choice" ;;
            esac
        done
    fi
}

# Ask what to do when barkchecker is already installed (sets $INSTALL_ACTION)
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
                1) INSTALL_ACTION="reinstall"; break ;;
                2) INSTALL_ACTION="remove";    break ;;
                3) INSTALL_ACTION="exit";      break ;;
                *) echo "Неверный выбор" ;;
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
                1) INSTALL_ACTION="reinstall"; break ;;
                2) INSTALL_ACTION="remove";    break ;;
                3) INSTALL_ACTION="exit";      break ;;
                *) echo "Invalid choice" ;;
            esac
        done
    fi
}

# Ensure the script has sudo privileges, exit if not granted
require_sudo() {
    sudo -v || exit 1
}

# Return 0 if the remote URL is reachable, non-zero otherwise
check_remote() {
    local url="$1"
    if check_tool curl; then
        curl -Is "$url" >/dev/null 2>&1
    elif check_tool wget; then
        wget --spider -q "$url"
    else
        return 127
    fi
}

# Download a file showing a progress bar (curl or wget)
download_with_progress() {
    local url="$1"
    local output="$2"
    if check_tool curl; then
        curl -fL --progress-bar "$url" -o "$output"
    elif check_tool wget; then
        wget --show-progress "$url" -O "$output"
    else
        return 127
    fi
}

# Download a file or return 1 with a localised error message.
# Also fails if the downloaded file is empty.
download_or_fail() {
    local url="$1"
    local output="$2"
    local fail_ru="$3"
    local fail_en="$4"

    if ! download_with_progress "$url" "$output"; then
        say_err "$fail_ru" "$fail_en"
        return 1
    fi

    if [[ ! -s "$output" ]]; then
        say_err "файл скачан пустым" "downloaded file is empty"
        return 1
    fi

    return 0
}

# Remove the installed binary and optionally the config directory,
# then exit the script.
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
            read -r -p "Удалить также $config_dir со всеми логами, базой и карантином? (д/н): " remove_config
            if [[ "$remove_config" == "д" || "$remove_config" == "Д" ]]; then
                rm -rf "$config_dir"
            fi
        else
            read -r -p "Remove $config_dir with all logs, database and quarantine too? (y/n): " remove_config
            if [[ "$remove_config" == "y" || "$remove_config" == "Y" ]]; then
                rm -rf "$config_dir"
            fi
        fi
    fi

    say "Удаление завершено." "Removal complete."
    exit 0
}

# Build raw-content URLs for the selected branch
prepare_urls() {
    BASE_URL="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$BRANCH"
    PROGRAM_URL="$BASE_URL/barkchecker"
    SH_DB_URL="$BASE_URL/db/sh.db"
    BUNDLE_DB_URL="$BASE_URL/db/bundle.db"
}

# Wrapper so spinner_run can call check_remote as a named function
_check_remote_program() {
    check_remote "$PROGRAM_URL"
}

# Create config dirs and log file, ensure they belong to the real user
_prepare_dirs() {
    mkdir -p "$CONFIG_DIR" "$DB_DIR" "$QUARANTINE_DIR"
    touch "$LOG_FILE"
    chown -R "$REAL_USER:$REAL_USER" "$CONFIG_DIR"
}

main() {
    # --- Paths ---
    INSTALL_PATH="/usr/local/bin/barkchecker"
    CONFIG_DIR="$REAL_HOME/.barkchecker"      # main config directory
    DB_DIR="$CONFIG_DIR/db"                   # signature databases
    QUARANTINE_DIR="$CONFIG_DIR/.quarantine"  # quarantined files
    SETTINGS_FILE="$CONFIG_DIR/settings.conf" # persistent settings
    LOG_FILE="$CONFIG_DIR/logs.log"           # activity log

    # Temporary download directory (cleaned up on exit or interrupt)
    TMP_DIR="/tmp/barkchecker_install"
    TMP_PROGRAM="$TMP_DIR/barkchecker"
    TMP_SH_DB="$TMP_DIR/sh.db"
    TMP_BUNDLE_DB="$TMP_DIR/bundle.db"

    # Register cleanup trap so /tmp is always removed on exit
    trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

    # Require curl or wget before doing anything else
    if ! check_tool curl && ! check_tool wget; then
        echo "Error: curl or wget is required" >&2
        exit 1
    fi

    choose_language

    # Handle already-installed case
    if [[ -x "$INSTALL_PATH" ]] || command -v barkchecker >/dev/null 2>&1; then
        ask_installed_action
        case "$INSTALL_ACTION" in
            reinstall) ;;
            remove)    remove_installation "$INSTALL_PATH" "$CONFIG_DIR" ;;
            exit)      say "Выход." "Exit."; exit 0 ;;
        esac
    fi

    choose_channel
    prepare_urls

    mkdir -p "$TMP_DIR"

    # Check GitHub reachability once; reuse result to avoid a second request
    spinner_run _check_remote_program \
        "Проверка доступа к GitHub..." \
        "Checking GitHub access..."
    remote_ok=$?

    if [[ $remote_ok -ne 0 ]]; then
        if [[ "$CHANNEL" == "beta" ]]; then
            # Beta branch unavailable — fall back to stable automatically
            say "Beta канал недоступен, переключаемся на stable..." \
                "Beta channel unavailable, falling back to stable..."
            CHANNEL="stable"
            BRANCH="main"
            prepare_urls

            spinner_run _check_remote_program \
                "Повторная проверка stable..." \
                "Re-checking stable..."

            if [[ $? -ne 0 ]]; then
                say_err "stable тоже недоступен" "stable is also unavailable"
                exit 1
            fi
        else
            say_err \
                "нет доступа к GitHub или файлы недоступны" \
                "cannot access GitHub or files are unavailable"
            exit 1
        fi
    fi

    # Download the main binary and both databases
    echo ""
    say "Скачивание Bark Checker..." "Downloading Bark Checker..."
    download_or_fail "$PROGRAM_URL" "$TMP_PROGRAM" \
        "не удалось скачать barkchecker" "failed to download barkchecker" || exit 1

    echo ""
    say "Скачивание базы sh.db..." "Downloading sh.db..."
    download_or_fail "$SH_DB_URL" "$TMP_SH_DB" \
        "не удалось скачать sh.db" "failed to download sh.db" || exit 1

    echo ""
    say "Скачивание базы bundle.db..." "Downloading bundle.db..."
    download_or_fail "$BUNDLE_DB_URL" "$TMP_BUNDLE_DB" \
        "не удалось скачать bundle.db" "failed to download bundle.db" || exit 1

    chmod +x "$TMP_PROGRAM"
    require_sudo

    # Create all required directories and the log file
    spinner_run _prepare_dirs \
        "Подготовка каталогов..." \
        "Preparing directories..."

    # Install binary to /usr/local/bin
    sudo mv "$TMP_PROGRAM" "$INSTALL_PATH" || {
        say_err \
            "не удалось переместить barkchecker в /usr/local/bin" \
            "failed to move barkchecker to /usr/local/bin"
        exit 1
    }

    sudo chmod +x "$INSTALL_PATH" || {
        say_err \
            "не удалось выдать права на выполнение" \
            "failed to set executable permissions"
        exit 1
    }

    # Copy databases into ~/.barkchecker/db/
    cp "$TMP_SH_DB" "$DB_DIR/sh.db" || {
        say_err "не удалось установить sh.db" "failed to install sh.db"
        exit 1
    }

    cp "$TMP_BUNDLE_DB" "$DB_DIR/bundle.db" || {
        say_err "не удалось установить bundle.db" "failed to install bundle.db"
        exit 1
    }

    # Write persistent settings (language, channel, first-run flag)
    cat > "$SETTINGS_FILE" <<EOF
LANGUAGE="$LANGUAGE"
CHANNEL="$CHANNEL"
FIRST_RUN="1"
EOF

    # Fix ownership of entire config directory so nothing belongs to root
    chown -R "$REAL_USER:$REAL_USER" "$CONFIG_DIR"

    echo ""
    say  "Установка завершена."            "Installation complete."
    say  "Язык: $LANGUAGE"                 "Language: $LANGUAGE"
    say  "Канал: $CHANNEL"                 "Channel: $CHANNEL"
    say  "Путь утилиты: $INSTALL_PATH"     "Program path: $INSTALL_PATH"
    say  "Папка конфигурации: $CONFIG_DIR" "Config directory: $CONFIG_DIR"
    echo ""
    say  "Запуск: barkchecker"             "Run: barkchecker"
}

main
