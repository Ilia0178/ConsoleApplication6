FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libssl-dev \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# сначала зависимости (лучше кеш)
COPY ConsoleApplication6.cpp .

RUN git clone --depth 1 https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && \
    cmake -B build -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
    cmake --build build -j$(nproc) && \
    cmake --install build

RUN g++ -O2 -std=c++17 -pthread \
    ConsoleApplication6.cpp \
    -o prime_checker \
    -lprometheus-cpp-core \
    -lprometheus-cpp-pull

FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/prime_checker /usr/local/bin/prime_checker
COPY --from=builder /usr/local/lib/libprometheus-cpp* /usr/local/lib/

RUN ldconfig

EXPOSE 8080 9090

ENTRYPOINT ["prime_checker"]