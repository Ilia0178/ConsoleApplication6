# =========================================================
# BUILD STAGE
# =========================================================
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y \
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
COPY . .

# =========================================================
# httplib (HTTP server header)
# =========================================================
RUN git clone https://github.com/yhirose/cpp-httplib.git /tmp/httplib && \
    mkdir -p /app/third_party && \
    cp /tmp/httplib/httplib.h /app/third_party/

# =========================================================
# prometheus-cpp
# =========================================================
RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
    make -j$(nproc) && make install && ldconfig

# =========================================================
# build app
# =========================================================
RUN g++ -Wall -Wextra -std=c++17 -O2 -pthread \
    -I/app/third_party \
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

COPY --from=builder /app/prime_checker /usr/local/bin/prime_checker
COPY --from=builder /usr/local/lib/libprometheus-cpp* /usr/local/lib/

RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/prometheus.conf && ldconfig

# ⚠️ порт должен совпадать с кодом (8080 или 9090)
EXPOSE 8080

CMD ["/usr/local/bin/prime_checker"]
