# =========================================================
# СТАДИЯ 1: СБОРКА (Builder)
# Используем ту же версию Ubuntu, что и в раннере GitHub
# =========================================================
FROM ubuntu:22.04 AS builder

# 1. Установка системных зависимостей (Этот слой закэшируется один раз и надолго)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git curl libcurl4-openssl-dev zlib1g-dev \
    libssl-dev ca-certificates dpkg-dev automake libtool && \
    rm -rf /var/lib/apt/lists/*

# 2. Сборка внешних библиотек (prometheus-cpp)
# Этот слой тоже будет закэширован. Он будет пересобираться, только если вы измените эту строку.
RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
    make -j$(nproc) && make install && ldconfig

# =========================================================
# СТАДИЯ 2: ФИНАЛЬНАЯ (Runtime)
# =========================================================
FROM ubuntu:22.04

# 1. Установка рантайм-зависимостей
RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 libcurl4 zlib1g libssl3 ca-certificates dpkg && \
    rm -rf /var/lib/apt/lists/*

# 2. Копирование и установка .deb пакета
# Docker Buildx увидит этот файл в контексте, потому что мы скачали его в пайплайне
COPY *.deb /tmp/prime-checker.deb

RUN dpkg -i /tmp/prime-checker.deb && rm /tmp/prime-checker.deb

# 3. Финальная настройка библиотек
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/prometheus.conf && ldconfig

# 4. Настройки запуска
ENV LD_LIBRARY_PATH=/usr/local/lib
EXPOSE 8080 9090

CMD ["/usr/local/bin/prime_checker"]