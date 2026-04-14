# =========================================================
# BUILD STAGE
# =========================================================
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libssl-dev \
    ca-certificates

WORKDIR /app
COPY . .

RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
    make -j$(nproc) && make install

RUN g++ -Wall -Wextra -std=c++17 -O2 -pthread \
    ConsoleApplication6.cpp -o prime_checker \
    -lprometheus-cpp-core -lprometheus-cpp-pull


# =========================================================
# RUNTIME STAGE
# =========================================================
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 \
    libcurl4 \
    zlib1g \
    libssl3 \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# бинарник
COPY --from=builder /app/prime_checker /usr/local/bin/prime_checker

# библиотеки Prometheus (ВАЖНО)
COPY --from=builder /usr/local/lib/libprometheus-cpp* /usr/local/lib/

# фикс линковки
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/prometheus.conf && ldconfig

EXPOSE 9090

CMD ["/usr/local/bin/prime_checker"]