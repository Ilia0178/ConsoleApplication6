# ====================================================================
# Настройки проекта
# ====================================================================

# Имя исполняемого файла
TARGET = prime-checker

# Имя исходного файла
SRC = ConsoleApplication4.cpp

# Компилятор C++
CXX = g++

# Флаги компиляции:
CXXFLAGS = -Wall -Wextra -std=c++17 -O2

# Имя временной папки и DEB файла
PKG_NAME = prime-checker-1.0
DEB_FILE = $(PKG_NAME).deb

# ====================================================================
# Цели 
# ====================================================================

# Цель по умолчанию 
.PHONY: all
all: $(TARGET)

# --------------------------------------------------------------------
# Подготовка среды (Установка зависимостей)
# --------------------------------------------------------------------
.PHONY: setup
setup:
	@echo "--- Checking and installing necessary build tools via apt ---"
	@command -v apt >/dev/null 2>&1 || { \
        echo >&2 "ERROR: apt package manager not found. This script is for Debian/Ubuntu systems."; \
        exit 1; \
    }
	# Установка build-essential (для компиляции) и dpkg-dev (для создания .deb)
	sudo apt update && sudo apt install -y build-essential dpkg-dev

# --------------------------------------------------------------------
# 1. Сборка 
# --------------------------------------------------------------------
$(TARGET): setup $(SRC)
	@echo "--- Компиляция $(SRC) с флагами: $(CXXFLAGS) ---"
	$(CXX) $(CXXFLAGS) $(SRC) -o $(TARGET)


# --------------------------------------------------------------------
# 2. Создание пакета DEB 
# --------------------------------------------------------------------
.PHONY: package
package: clean setup all
	@echo "--- Подготовка структуры пакета DEB ---"
	
	# Проверка dpkg-deb
	@command -v dpkg-deb >/dev/null 2>&1 || { \
        echo >&2 "ERROR: dpkg-deb tool not found even after setup."; \
        exit 1; \
    }
	
	# 1. Создание временной структуры
	rm -rf $(PKG_NAME)
	mkdir -p $(PKG_NAME)/usr/bin
	
	# 2. Копирование готового исполняемого файла
	cp $(TARGET) $(PKG_NAME)/usr/bin/
	
	# 3. Создание директории DEBIAN и файла control
	mkdir -p $(PKG_NAME)/DEBIAN
	echo "Package: prime-checker" > $(PKG_NAME)/DEBIAN/control
	echo "Version: 1.0" >> $(PKG_NAME)/DEBIAN/control
	echo "Architecture: amd64" >> $(PKG_NAME)/DEBIAN/control
	echo "Maintainer: Team Name <team.email@example.com>" >> $(PKG_NAME)/DEBIAN/control 

	echo "Depends: build-essential" >> $(PKG_NAME)/DEBIAN/control 
	echo "Description: A simple C++ prime number checker tool for command line." >> $(PKG_NAME)/DEBIAN/control

	# 4. Сборка .deb пакета
	dpkg-deb --build $(PKG_NAME)
	rm -rf $(PKG_NAME)
	rm -f $(TARGET)
	@echo "--------------------------------------------------------------------"
	@echo "SUCCESS: DEB package created: $(DEB_FILE)"
	@echo "--------------------------------------------------------------------"

# --------------------------------------------------------------------
# 3. Установка созданного пакета
# --------------------------------------------------------------------
.PHONY: install
install: package
	@echo "--- Installing the generated DEB package using apt ---"
	sudo apt install -y ./$(DEB_FILE)

# --------------------------------------------------------------------
# Очистка
# --------------------------------------------------------------------
.PHONY: clean
clean:
	@echo "Очистка сгенерированных файлов..."
	rm -f $(TARGET)
	rm -f $(DEB_FILE)
	rm -rf $(PKG_NAME)