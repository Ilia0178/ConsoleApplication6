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
    libssl3 \ # <-- Заменили libssl1.1 на libssl3
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder --chown=root:root /app/prime_checker /usr/bin/prime_checker
COPY --from=builder --chown=root:root /usr/local/lib/libprometheus-cpp* /usr/local/lib/
RUN ldconfig

RUN chmod +x /usr/bin/prime_checker

EXPOSE 9090

ENTRYPOINT ["/usr/bin/prime_checker"]