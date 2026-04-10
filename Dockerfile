# ===================================================================
# ЭТАП 1: Builder
# ===================================================================
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
# Добавляем --recursive для скачивания подмодулей, включая civetweb
RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prometheus-cpp && \
    cd /tmp/prometheus-cpp && \
    mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
    make -j$(nproc) && make install && ldconfig

RUN g++ -Wall -Wextra -std=c++17 -O2 -pthread \
    ConsoleApplication6.cpp -o prime_checker \
    -lprometheus-cpp-core -lprometheus-cpp-pull

# ===================================================================
# ЭТАП 2: Финальный образ
# ===================================================================
FROM ubuntu:22.04

# Устанавливаем только необходимые библиотеки для запуска
RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 \
    libcurl4 \
    zlib1g \
    libssl1.1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Копируем скомпилированный бинарник
COPY --from=builder --chown=root:root /app/prime_checker /usr/bin/prime_checker

# Копируем динамические библиотеки prometheus-cpp
COPY --from=builder --chown=root:root /usr/local/lib/libprometheus-cpp* /usr/local/lib/
# Копируем другие библиотеки, если они были установлены в /usr/local/lib
# Пример: COPY --from=builder --chown=root:root /usr/local/lib/*.so /usr/local/lib/

# Обновляем кэш динамических загрузчиков
RUN ldconfig

# Делаем бинарник исполняемым
RUN chmod +x /usr/bin/prime_checker

# Порт, на котором будет слушать приложение (если оно слушает)
EXPOSE 9090

# Команда для запуска приложения
ENTRYPOINT ["/usr/bin/prime_checker"]