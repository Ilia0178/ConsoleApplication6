# =========================================================
# СТАДИЯ СБОРКИ (Builder)
# Используем Ubuntu 22.04 как базовый образ
# =========================================================
FROM ubuntu:22.04 AS builder

# Устанавливаем инструменты для сборки
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    curl \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libssl-dev \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Копируем исходный код
COPY . .

# Установка зависимостей (httplib)
RUN git clone https://github.com/yhirose/cpp-httplib.git /tmp/httplib && \
    mkdir -p third_party && \
    cp /tmp/httplib/httplib.h third_party/

# Установка Prometheus-cpp (собираем из исходников)
RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
    make -j$(nproc) && make install && ldconfig

# Компиляция вашего приложения
# Замените ConsoleApplication6.cpp на имя вашего файла с main()
RUN g++ -Wall -Wextra -std=c++17 -O2 -pthread \
    -Ithird_party \
    ConsoleApplication6.cpp -o prime_checker \
    -lprometheus-cpp-core -lprometheus-cpp-pull

# =========================================================
# ФИНАЛЬНАЯ СТАДИЯ (Runtime)
# =========================================================
FROM ubuntu:22.04

# Устанавливаем только необходимые рантайм-библиотеки
RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 \
    libcurl4 \
    zlib1g \
    libssl3 \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Копируем бинарник из стадии сборки
COPY --from=builder /app/prime_checker /usr/local/bin/prime_checker

# Копируем скомпилированные библиотеки Prometheus
COPY --from=builder /usr/local/lib/libprometheus-cpp* /usr/local/lib/

# Настраиваем пути для поиска динамических библиотек
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/prometheus.conf && ldconfig

# Открываем порты (8080 - приложение, 9090 - метрики)
EXPOSE 8080 9090

# Запуск приложения
ENTRYPOINT ["/usr/local/bin/prime_checker"]