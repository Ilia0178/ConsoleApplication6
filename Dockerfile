# =========================================================
# BUILD STAGE
# =========================================================
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# -------------------------------
# stable system dependencies (CI-safe)
# -------------------------------
RUN set -eux; \
    apt-get update -o Acquire::Retries=5 -o Acquire::ForceIPv4=true; \
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

# -------------------------------
# prometheus-cpp (STATIC build — IMPORTANT FIX)
# -------------------------------
RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && mkdir build && cd build && \
    cmake .. \
        -DBUILD_SHARED_LIBS=OFF \
        -DENABLE_PUSH=OFF && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# -------------------------------
# build application
# -------------------------------
RUN g++ -Wall -Wextra -std=c++17 -O2 -pthread \
    ConsoleApplication6.cpp \
    -o prime_checker \
    -lprometheus-cpp-core \
    -lprometheus-cpp-pull


# =========================================================
# RUNTIME STAGE (minimal)
# =========================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    apt-get update -o Acquire::Retries=5 -o Acquire::ForceIPv4=true; \
    apt-get install -y --no-install-recommends \
        libcurl4 \
        zlib1g \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/prime_checker /usr/bin/prime_checker

RUN chmod +x /usr/bin/prime_checker

EXPOSE 8080 9090

ENTRYPOINT ["/usr/bin/prime_checker"]
