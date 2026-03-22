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
