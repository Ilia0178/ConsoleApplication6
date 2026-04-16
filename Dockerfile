# =========================================================
# 1. BUILD STAGE
# =========================================================
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -o Acquire::Retries=5 -o Acquire::ForceIPv4=true && \
    apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        g++ \
        make \
        libcurl4-openssl-dev \
        zlib1g-dev \
        libssl-dev \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# prometheus-cpp (static = безопасно)
RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=OFF -DENABLE_PUSH=OFF && \
    make -j$(nproc) && \
    make install && ldconfig

# build your app
RUN g++ -std=c++17 -O2 -pthread \
    ConsoleApplication6.cpp \
    -o prime_checker \
    -lprometheus-cpp-core -lprometheus-cpp-pull


# =========================================================
# 2. RUNTIME STAGE
# =========================================================
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    libstdc++6 \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/prime_checker /app/prime_checker

RUN chmod +x /app/prime_checker

EXPOSE 8080
EXPOSE 9090

ENTRYPOINT ["/app/prime_checker"]
