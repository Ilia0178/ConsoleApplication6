# ================================
# BUILDER STAGE
# ================================
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    curl \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libssl-dev \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ================================
# copy source first (better cache)
# ================================
COPY ConsoleApplication6.cpp .
COPY Makefile .

# ================================
# httplib header
# ================================
RUN mkdir -p /app/third_party && \
    curl -L https://raw.githubusercontent.com/yhirose/cpp-httplib/master/httplib.h \
    -o /app/third_party/httplib.h

# ================================
# prometheus-cpp build
# ================================
RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && \
    mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# ================================
# build app
# ================================
RUN g++ -O2 -std=c++17 -pthread \
    -I/app/third_party \
    ConsoleApplication6.cpp \
    -o prime_checker \
    -lprometheus-cpp-core \
    -lprometheus-cpp-pull


# ================================
# RUNTIME STAGE (minimal)
# ================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 🔥 minimal runtime dependencies ONLY
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# binary only
COPY --from=builder /app/prime_checker /usr/local/bin/prime_checker

# prometheus libs (needed for runtime linking)
COPY --from=builder /usr/local/lib/libprometheus-cpp* /usr/local/lib/

RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/prometheus.conf && ldconfig

# ports
EXPOSE 8080
EXPOSE 9090

# run
CMD ["/usr/local/bin/prime_checker"]
