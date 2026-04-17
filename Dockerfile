# =========================
# STAGE 1: Builder
# Используем Ubuntu 22.04 как основу для сборки
# =========================
FROM ubuntu:22.04 AS builder

LABEL stage=builder

# Устанавливаем только необходимые инструменты: компилятор, make, wget, git
# и development версии библиотек, которые нужны для компиляции.
RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ \
    make \
    wget \
    git \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Копируем весь исходный код проекта в контейнер, в каталог /src
COPY . /src
WORKDIR /src

# Определяем переменные, которые использовались в вашем Makefile.
# Они должны быть актуальны для вашего проекта.
# SRC = ConsoleApplication6.cpp (судя по вашему Makefile)
# TARGET = prime_checker (судя по вашему Makefile)
# CXXFLAGS = -Wall -Wextra -std=c++17 -O2 -pthread -I. -I/usr/local/include
# LDFLAGS = -L/usr/local/lib -lprometheus-cpp-core -lprometheus-cpp-pull

# Собираем приложение напрямую с g++
# Предполагается, что prometheus-cpp и httplib.h установлены или скопированы так,
# чтобы CXXFLAGS и LDFLAGS их нашли.
# Если prometheus-cpp установлен в /usr/local/lib (как в вашем Makefile 'prom' цели),
# то LDFLAGS уже должны работать.
RUN g++ \
    -Wall -Wextra -std=c++17 -O2 -pthread -I. -I/usr/local/include \
    ConsoleApplication6.cpp \
    -o prime_checker \
    -L/usr/local/lib -lprometheus-cpp-core -lprometheus-cpp-pull && \
    # Перемещаем собранный бинарник в каталог, который будем копировать в runtime стадию
    mkdir -p /build && \
    mv prime_checker /build/prime_checker

# =========================
# STAGE 2: Runtime
# Используем чистый образ Ubuntu 22.04 для финального образа.
# =========================
FROM ubuntu:22.04

LABEL stage=runtime

# Устанавливаем только runtime-зависимости.
# libcurl4, libssl3 - это runtime-версии библиотек.
# Важно: prometheus-cpp должен быть установлен так, чтобы быть доступным для запуска.
# Если prometheus-cpp был установлен в /usr/local/lib вашим Makefile,
# то эти библиотеки должны быть доступны.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4 \
    libssl3 \
    ca-certificates \
    # Если prometheus-cpp не устанавливается через apt, и вы его собирали и устанавливали
    # в builder'е в /usr/local/lib, то в runtime стадии вам нужно его скопировать
    # или установить его также и сюда.
    # Для простоты, предполагаем, что он уже установлен в /usr/local/lib
    # или может быть установлен через apt, если такая версия есть.
    # Проверьте: apt-cache search libprometheus-cpp-core (может отличаться название)
    && rm -rf /var/lib/apt/lists/*

# Копируем только скомпилированный бинарник из стадии builder.
COPY --from=builder /build/prime_checker /usr/local/bin/prime_checker

# Копируем заголовочный файл httplib.h, если он нужен для работы (например, для логирования).
# Если он не нужен для runtime, то эту строку можно убрать.
COPY --from=builder /src/third_party/httplib.h /usr/local/include/httplib.h

# Устанавливаем права на исполнение для нашего бинарника
RUN chmod +x /usr/local/bin/prime_checker

# Устанавливаем переменную окружения LD_LIBRARY_PATH, чтобы система могла найти
# динамические библиотеки.
ENV LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}

# Открываем порты
EXPOSE 8080
EXPOSE 9090

# Команда для запуска приложения
CMD ["/usr/local/bin/prime_checker"]