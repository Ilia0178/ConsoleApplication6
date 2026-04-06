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
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN git clone https://github.com/jupp0r/prometheus-cpp.git /tmp/prometheus-cpp && \
    cd /tmp/prometheus-cpp && \
    mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
    make -j4 && make install && ldconfig

RUN g++ -Wall -Wextra -std=c++17 -O2 -pthread \
    ConsoleApplication6.cpp -o prime_checker \
    -lprometheus-cpp-core -lprometheus-cpp-pull

# ===================================================================
# ЭТАП 2: Финальный образ
# ===================================================================
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    libstdc++6 \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/*


COPY --from=builder /app/prime_checker /usr/bin/prime_checker

COPY --from=builder /usr/local/lib/libprometheus-cpp* /usr/local/lib/
RUN ldconfig

RUN chmod +x /usr/bin/prime_checker

EXPOSE 9090

ENTRYPOINT ["/usr/bin/prime_checker"]