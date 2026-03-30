# ===================================================================
# 1 Сборка приложения
# ===================================================================
FROM ubuntu:22.04 AS builder

# Установка инструментов для сборки
RUN apt-get update && \
    apt-get install -y build-essential && \
    rm -rf /var/lib/apt/lists/*

COPY . /app
WORKDIR /app

# Компиляция приложения
RUN make build

# ===================================================================
# 2 Создание DEB пакета
# ===================================================================
FROM ubuntu:22.04 AS deb_package

# Установка только инструментов для упаковки
RUN apt-get update && \
    apt-get install -y dpkg-dev make && \
    rm -rf /var/lib/apt/lists/*

COPY . /app
WORKDIR /app

# Копируем собранный бинарник из этапа builder
# Убедимся, что он лежит в /app/ для make package
COPY --from=builder /app/prime_checker /app/prime_checker

# Создаем .deb пакет.
# ВАЖНО: Убедитесь, что ваш Makefile (цель 'package')
# использует prime_checker, который уже есть в /app/
# (то есть, не запускает make build снова).
# Если make package сам копирует бинарник в структуру пакета,
# он должен брать именно этот /app/prime_checker.
RUN make package

# ===================================================================
# 3 Финальный образ
# ===================================================================
FROM ubuntu:22.04

# Установка только dpkg для установки .deb пакета
RUN apt-get update && \
    apt-get install -y dpkg && \
    rm -rf /var/lib/apt/lists/*

# Копируем созданный .deb пакет из этапа deb_package
COPY --from=deb_package /app/*.deb /app/

# Устанавливаем .deb пакет, удаляем временный файл .deb и директорию /app
RUN dpkg -i /app/*.deb && \
    rm /app/*.deb && \
    rm -rf /app

ENTRYPOINT ["prime_checker"]