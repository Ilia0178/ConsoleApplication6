FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libssl-dev \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# httplib
RUN mkdir -p /app/third_party && \
    curl -L https://raw.githubusercontent.com/yhirose/cpp-httplib/master/httplib.h \
    -o /app/third_party/httplib.h

# prometheus-cpp
RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
    make -j$(nproc) && make install && ldconfig

# build app
RUN g++ -Wall -Wextra -std=c++17 -O2 -pthread \
    -I/app/third_party \
    ConsoleApplication6.cpp -o prime_checker \
    -lprometheus-cpp-core -lprometheus-cpp-pull


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

EXPOSE 8080

CMD ["/usr/local/bin/prime_checker"]