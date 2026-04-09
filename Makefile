# ====================================================================
# Настройки проекта
# ====================================================================
TARGET = prime_checker
SRC = ConsoleApplication6.cpp
CXX = g++
# -pthread для поддержки потоков
CXXFLAGS = -Wall -Wextra -std=c++17 -O2 -pthread -I/usr/local/include
# библиотеки для Prometheus
LDFLAGS = -L/usr/local/lib -lprometheus-cpp-core -lprometheus-cpp-pull
PKG_NAME = prime-checker
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
	@echo "--- Проверка и установка зависимостей ---"
	@$(SUDO) apt update
	@$(SUDO) apt install -y build-essential dpkg-dev libcurl4-openssl-dev zlib1g-dev
	@echo "Зависимости установлены."

# --------------------------------------------------------------------
# 1. Сборка 
# --------------------------------------------------------------------
.PHONY: build
build: setup $(SRC)
	$(CXX) $(CXXFLAGS) $(SRC) -o $(TARGET) $(LDFLAGS)

# --------------------------------------------------------------------
# 2. Тестирование
# --------------------------------------------------------------------
.PHONY: test
test:
	@echo "--- Запуск тестов ---"
	
	# --- Тест для 17 (простое число) ---
	# Захватываем весь вывод (stdout и stderr) в переменную OUTPUT
	OUTPUT=$(shell echo "17" | ./$(TARGET) 2>&1)
	# Проверяем, содержит ли вывод строку "17 is a prime number."
	echo "$$OUTPUT" | grep -F "17 is a prime number." || { echo "FAIL: 17"; echo "Output was: $$OUTPUT"; exit 1; }
	
	# --- Тест для 18 (не простое число) ---
	OUTPUT=$(shell echo "18" | ./$(TARGET) 2>&1)
	echo "$$OUTPUT" | grep -F "18 is not a prime number." || { echo "FAIL: 18"; echo "Output was: $$OUTPUT"; exit 1; }
	
	# --- Тест для некорректного ввода (abc) ---
	# Ожидаем ошибку "Invalid input." в stderr, поэтому собираем оба потока (2>&1)
	OUTPUT=$(shell echo "abc" | ./$(TARGET) 2>&1)
	echo "$$OUTPUT" | grep -F "Invalid input." || { echo "FAIL: abc"; echo "Output was: $$OUTPUT"; exit 1; }
	
	# --- Тест для 0 (вне диапазона) ---
	# Ожидаем ошибку "Error: Number is out of range..." в stderr
	OUTPUT=$(shell echo "0" | ./$(TARGET) 2>&1)
	echo "$$OUTPUT" | grep -F "Error: Number is out of range (1 - 2 billion)." || { echo "FAIL: 0"; echo "Output was: $$OUTPUT"; exit 1; }
	
	# --- Тест для 2000000000 (граничное значение, не простое) ---
	OUTPUT=$(shell echo "2000000000" | ./$(TARGET) 2>&1)
	echo "$$OUTPUT" | grep -F "2000000000 is not a prime number." || { echo "FAIL: 2000000000"; echo "Output was: $$OUTPUT"; exit 1; }
	
	# --- Тест для 2000000001 (вне диапазона) ---
	# Ожидаем ошибку "Error: Number is out of range..." в stderr
	OUTPUT=$(shell echo "2000000001" | ./$(TARGET) 2>&1)
	echo "$$OUTPUT" | grep -F "Error: Number is out of range (1 - 2 billion)." || { echo "FAIL: 2000000001"; echo "Output was: $$OUTPUT"; exit 1; }
	
	@echo "--- Тесты пройдены ---"



# --------------------------------------------------------------------
# 3. Упаковка 
# --------------------------------------------------------------------
.PHONY: package
package:
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