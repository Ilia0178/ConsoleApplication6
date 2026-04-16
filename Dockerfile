FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y \
    build-essential cmake git curl \
    libcurl4-openssl-dev zlib1g-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN git clone https://github.com/yhirose/cpp-httplib.git /tmp/httplib && \
    mkdir -p third_party && \
    cp /tmp/httplib/httplib.h third_party/

RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
    make -j$(nproc) && make install

RUN g++ -std=c++17 -O2 -pthread \
    -Ithird_party \
    ConsoleApplication6.cpp -o prime_checker \
    -lprometheus-cpp-pull -lprometheus-cpp-core

# ================= RUNTIME =================

FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    libstdc++6 libcurl4 zlib1g libssl3 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/prime_checker /usr/local/bin/
COPY --from=builder /usr/local/lib/libprometheus-cpp* /usr/local/lib/

RUN ldconfig

EXPOSE 8080 9090

CMD ["prime_checker"]