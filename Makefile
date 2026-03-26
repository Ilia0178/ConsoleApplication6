# ====================================================================
# Настройки проекта
# ====================================================================
TARGET = prime_checker
SRC = ConsoleApplication6.cpp
CXX = g++
CXXFLAGS = -Wall -Wextra -std=c++17 -O2
PKG_NAME = prime_checker-1.0
DEB_FILE = $(PKG_NAME).deb

# Цель по умолчанию 
.PHONY: all
all: build

# --------------------------------------------------------------------
# 0. Подготовка среды 
# --------------------------------------------------------------------
SUDO := $(shell command -v sudo >/dev/null 2>&1 && echo "sudo" || echo "")

.PHONY: setup
setup:
	@echo "--- Проверка и установка необходимых инструментов ---"
	@command -v apt >/dev/null 2>&1 || { \
        echo >&2 "ERROR: apt package manager not found."; \
        exit 1; \
    }
	
	@$(SUDO) apt update
	
	@dpkg -s build-essential >/dev/null 2>&1 || { \
        echo "Пакет build-essential не найден. Установка..."; \
        $(SUDO) apt install -y build-essential; \
    }
	
	@dpkg -s dpkg-dev >/dev/null 2>&1 || { \
        echo "Пакет dpkg-dev не найден. Установка..."; \
        $(SUDO) apt install -y dpkg-dev; \
    }
	@echo "Проверка зависимостей сборки завершена."
# --------------------------------------------------------------------
# 1. Сборка 
# --------------------------------------------------------------------
.PHONY: build
build: setup $(SRC)
	@echo "--- Компиляция $(SRC) ---"
	$(CXX) $(CXXFLAGS) $(SRC) -o $(TARGET)

# --------------------------------------------------------------------
# 2. Тестирование
# --------------------------------------------------------------------
.PHONY: test
test: build
	@echo "--- Запуск тестов ---"
	
	# Тест 1: Составное число (17)
	echo "17" | ./$(TARGET) 2>&1 | grep -q "is a prime number" || { echo "FAIL: 17"; exit 1; }
	
	# Тест 2: Составное число (18)
	echo "18" | ./$(TARGET) 2>&1 | grep -q "is not a prime number" || { echo "FAIL: 18"; exit 1; }

	# Тест 3: Некорректный ввод (abc)
	echo "abc" | ./$(TARGET) 2>&1 | grep -q "Error" || { echo "FAIL: abc"; exit 1; }
	
	@echo "Тест 4.1: Проверка нижней границы (0)..."
	echo "0" | ./$(TARGET) 2>&1 | grep -q "Error: Number is out of the valid range" || { echo "FAIL: 0"; exit 1; }

	# Тест 4.2: Верхняя граница (2,000,000,000) 
	@echo "Тест 4.2: Проверка верхней границы (2000000000)..."
	echo "2000000000" | ./$(TARGET) 2>&1 | grep -q "is not a prime number" || { echo "FAIL: 2000000000"; exit 1; }

	# Тест 4.3: Выход за верхнюю границу (2,000,000,001) - Ожидается ошибка диапазона
	@echo "Тест 4.3: Проверка выхода за границу (2000000001)..."
	echo "2000000001" | ./$(TARGET) 2>&1 | grep -q "Error: Number is out of the valid range" || { echo "FAIL: 2000000001"; exit 1; }

	@echo "--- Тесты пройдены ---"

# --------------------------------------------------------------------
# 3. Упаковка 
# --------------------------------------------------------------------
.PHONY: package
package: build test  
	@echo "--- Создание пакета .deb ---"
	
	# Подготовка структуры
	mkdir -p $(PKG_NAME)/usr/bin
	
	# Копирование скомпилированного файла в структуру пакета
	cp $(TARGET) $(PKG_NAME)/usr/bin/
	
	# Создание control-файла
	mkdir -p $(PKG_NAME)/DEBIAN
	echo "Package: prime-checker" > $(PKG_NAME)/DEBIAN/control
	echo "Version: 1.0" >> $(PKG_NAME)/DEBIAN/control
	echo "Architecture: amd64" >> $(PKG_NAME)/DEBIAN/control
	echo "Maintainer: Team Name <team.email@example.com>" >> $(PKG_NAME)/DEBIAN/control 
	echo "Depends: libc6 (>= 2.29), libstdc++6 (>= 9)" >> $(PKG_NAME)/DEBIAN/control 
	echo "Description: A simple C++ prime number checker tool." >> $(PKG_NAME)/DEBIAN/control

	# Сборка пакета
	dpkg-deb --build $(PKG_NAME)
	
	rm -rf $(PKG_NAME)
	rm -f $(TARGET)

# --------------------------------------------------------------------
# 4. Установка созданного пакета 
# --------------------------------------------------------------------
.PHONY: install
install: package
	@echo "--- Установка пакета (зависимости будут скачаны автоматически) ---"
	sudo apt install -y ./$(DEB_FILE)