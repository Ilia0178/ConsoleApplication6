# =========================================================
# СТАДИЯ 1: СБОРКА (Builder)
# =========================================================
FROM ubuntu:22.04 AS builder

# Устанавливаем инструменты
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git curl libcurl4-openssl-dev zlib1g-dev libssl-dev ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Сборка библиотек и приложения (ваши RUN команды из предыдущего сообщения)
RUN git clone https://github.com/yhirose/cpp-httplib.git /tmp/httplib && \
    mkdir -p third_party && cp /tmp/httplib/httplib.h third_party/

RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
    make -j$(nproc) && make install && ldconfig

RUN g++ -Wall -Wextra -std=c++17 -O2 -pthread \
    -Ithird_party ConsoleApplication6.cpp -o prime_checker \
    -lprometheus-cpp-core -lprometheus-cpp-pull

# =========================================================
# СТАДИЯ 2: ФИНАЛЬНАЯ (Runtime)
# =========================================================
FROM ubuntu:22.04

# 1. Установка базовых библиотек (соответствует слою №6 в вашем логе)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 libcurl4 zlib1g libssl3 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 2. Копирование бинарника (слой №7)
COPY --from=builder /app/prime_checker /usr/local/bin/prime_checker

# 3. Копирование библиотек (слой №8)
COPY --from=builder /usr/local/lib/libprometheus-cpp* /usr/local/lib/

# 4. Настройка библиотек (слой №9)
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/prometheus.conf && ldconfig

# 5. Установка переменной окружения (слой №10)
ENV LD_LIBRARY_PATH=/usr/local/lib

# 6. Порты (слой №11)
EXPOSE 8080 9090

# 7. Запуск (слой №12)
CMD ["/usr/local/bin/prime_checker"]