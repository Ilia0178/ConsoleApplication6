# =========================================================
# СТАДИЯ 1: СБОРКА (Builder)
# =========================================================
FROM ubuntu:22.04 AS builder

# Устанавливаем инструменты для сборки + инструменты для создания deb
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    curl \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libssl-dev \
    ca-certificates \
    dpkg-dev \
    automake \
    libtool && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Установка зависимостей (httplib)
RUN git clone https://github.com/yhirose/cpp-httplib.git /tmp/httplib && \
    mkdir -p third_party && cp /tmp/httplib/httplib.h third_party/

# Установка Prometheus-cpp (собираем из исходников)
RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
    make -j$(nproc) && make install && ldconfig

# Компиляция вашего приложения
RUN g++ -Wall -Wextra -std=c++17 -O2 -pthread \
    -Ithird_party ConsoleApplication6.cpp -o prime_checker \
    -lprometheus-cpp-core -lprometheus-cpp-pull

# Создание .deb пакета из скомпилированного бинарника
# Убедитесь, что у вас есть debian/control файл и другие необходимые файлы для dpkg-buildpackage
# Для простоты, можно создать временный пакет:
RUN dpkg-deb --build /app /app/prime-checker.deb

# =========================================================
# СТАДИЯ 2: ФИНАЛЬНАЯ (Runtime)
# =========================================================
FROM ubuntu:22.04

# Устанавливаем только необходимые рантайм-библиотеки + dpkg
RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 \
    libcurl4 \
    zlib1g \
    libssl3 \
    ca-certificates \
    dpkg && \
    rm -rf /var/lib/apt/lists/*

# Копируем .deb пакет из стадии сборки
COPY --from=builder /app/prime-checker.deb /tmp/prime-checker.deb

# Устанавливаем .deb пакет
RUN dpkg -i /tmp/prime-checker.deb && rm /tmp/prime-checker.deb

# Настраиваем пути для поиска динамических библиотек (они должны установиться из .deb)
# Если .deb пакет корректно установил файлы в /usr/local/lib, ldconfig сработает
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/prometheus.conf && ldconfig

# Открываем порты (8080 - приложение, 9090 - метрики)
EXPOSE 8080 9090

# Запуск приложения
CMD ["/usr/local/bin/prime_checker"]