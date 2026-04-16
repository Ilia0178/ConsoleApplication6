# =========================================================
# BUILD STAGE
# =========================================================
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    g++ \
    make \
    cmake \
    git \
    wget \
    curl \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# =========================================================
# httplib (fixed version)
# =========================================================
RUN mkdir -p third_party && \
    wget -q -O third_party/httplib.h \
    https://raw.githubusercontent.com/yhirose/cpp-httplib/v0.15.3/httplib.h

# =========================================================
# prometheus-cpp (pinned version, static build)
# =========================================================
RUN git clone --branch v1.2.4 --recursive \
    https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && mkdir build && cd build && \
    cmake .. \
      -DBUILD_SHARED_LIBS=OFF \
      -DENABLE_PUSH=OFF && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# =========================================================
# BUILD APP (single source of truth = Makefile)
# =========================================================
RUN make build


# =========================================================
# RUNTIME STAGE
# =========================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4 \
    zlib1g \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# copy only binary
COPY --from=builder /app/prime_checker /usr/local/bin/prime_checker

RUN chmod +x /usr/local/bin/prime_checker

EXPOSE 8080 9090

CMD ["prime_checker"]