# Bark Checker

Lightweight security tool for scanning `.sh`, `.bundle` and executable files.

---

## Features

- Scan `.sh`, `.bundle`, and executable files
- Detect dangerous commands
- Analyze curl / wget downloads
- Detect curl | bash
- Categorized database (critical / warning / info)
- Quarantine system
- Multi-language support (RU / EN)
- Logging system

---

## Badges

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-linux-orange?logo=linux)
![Status](https://img.shields.io/badge/status-stable-brightgreen)
![GitHub](https://img.shields.io/badge/github-sergo--linux-blue?logo=github)

---

## Installation

Download and run the installer from the latest release:

curl -fsSL https://github.com/sergo-linux/barkchecker/releases/latest/download/install.sh | bash

---

## Usage

Go to folder with file

enter command barkchecker

---

## Commands

--help        Show help  
--version     Show program version  
--dbver       Show database version  
--logs        Show logs  
--lang        Change language  
--beta        Switch to beta channel  
--stable      Switch to stable channel  
--update      Update program and database  

---

## Example Output

[CRITICAL] Forbidden pattern detected  
  Category: destructive  
  Pattern: rm -rf /  
  Line: 2  
  Content: rm -rf /  

Critical patterns detected: 1  
Move file to quarantine? (y/n):  

---

## How It Works

Bark Checker uses a pattern-based detection system:

- Reads patterns from database files  
- Scans files line-by-line  
- Matches known dangerous commands  
- Extracts network payloads (curl / wget)  
- Detects unsafe execution patterns  

---

## Logs

~/.barkchecker/logs.log

---

## Quarantine

~/.barkchecker/.quarantine

---

## Releases

https://github.com/sergo-linux/barkchecker/releases

---

## Author

GitHub: sergo-linux

---

## License

MIT License © 2026 sergo-linux

---

## Disclaimer

This tool is provided for educational and security purposes only.  
Use at your own risk.
