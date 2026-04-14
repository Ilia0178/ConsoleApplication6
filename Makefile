# ====================================================================
# Настройки проекта
# ====================================================================
TARGET = prime_checker
SRC = ConsoleApplication6.cpp
CXX = g++

CXXFLAGS = -Wall -Wextra -std=c++17 -O2 -pthread -I/usr/local/include
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
# 2. Тестирование (FIXED LD_LIBRARY_PATH)
# --------------------------------------------------------------------
.PHONY: test
test:
	@echo "--- Запуск тестов ---"
	LD_LIBRARY_PATH="/usr/local/lib:$$LD_LIBRARY_PATH" \
	echo "--- Тест 17 ---" && \
	OUTPUT=$$(echo "17" | ./$(TARGET) 2>&1) && \
	echo "$$OUTPUT" | grep "17 is a prime number." || { echo "FAIL: 17"; echo "$$OUTPUT"; exit 1; } && \
	\
	echo "--- Тест 18 ---" && \
	OUTPUT=$$(echo "18" | ./$(TARGET) 2>&1) && \
	echo "$$OUTPUT" | grep "18 is not a prime number." || { echo "FAIL: 18"; echo "$$OUTPUT"; exit 1; } && \
	\
	echo "--- Тест abc ---" && \
	OUTPUT=$$(echo "abc" | ./$(TARGET) 2>&1) && \
	echo "$$OUTPUT" | grep "Error: Input is not a valid number." || { echo "FAIL: abc"; echo "$$OUTPUT"; exit 1; } && \
	\
	echo "--- Тест 0 ---" && \
	OUTPUT=$$(echo "0" | ./$(TARGET) 2>&1) && \
	echo "$$OUTPUT" | grep "Error: Number is out of the valid range (1 - 2 billion)." || { echo "FAIL: 0"; echo "$$OUTPUT"; exit 1; } && \
	\
	echo "--- Тест 2000000001 ---" && \
	OUTPUT=$$(echo "2000000001" | ./$(TARGET) 2>&1) && \
	echo "$$OUTPUT" | grep "Error: Number is out of the valid range (1 - 2 billion)." || { echo "FAIL: 2000000001"; echo "$$OUTPUT"; exit 1; } && \
	\
	echo "--- Все тесты пройдены ---"

# --------------------------------------------------------------------
# 3. Упаковка (.deb) (FIXED: НЕ удаляем бинарник)
# --------------------------------------------------------------------
.PHONY: package
package:
	@echo "--- Создание пакета .deb ---"

	mkdir -p $(PKG_NAME)/usr/bin
	cp $(TARGET) $(PKG_NAME)/usr/bin/

	mkdir -p $(PKG_NAME)/DEBIAN

	echo "Package: prime-checker" > $(PKG_NAME)/DEBIAN/control
	echo "Version: 1.0" >> $(PKG_NAME)/DEBIAN/control
	echo "Architecture: amd64" >> $(PKG_NAME)/DEBIAN/control
	echo "Maintainer: Team Name <team.email@example.com>" >> $(PKG_NAME)/DEBIAN/control
	echo "Depends: libc6 (>= 2.29), libstdc++6 (>= 9)" >> $(PKG_NAME)/DEBIAN/control
	echo "Description: A simple C++ prime number checker tool." >> $(PKG_NAME)/DEBIAN/control

	dpkg-deb --build $(PKG_NAME)

	rm -rf $(PKG_NAME)
	@echo "--- Package created successfully ---"

# --------------------------------------------------------------------
# 4. Install
# --------------------------------------------------------------------
.PHONY: install
install: package
	@echo "--- Installing package ---"
	sudo apt install -y ./$(DEB_FILE)