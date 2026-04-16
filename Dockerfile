# =========================
# BUILD STAGE
# =========================
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    curl \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# =========================
# source first (better cache)
# =========================
COPY ConsoleApplication6.cpp .

# =========================
# httplib header (no git clone)
# =========================
RUN mkdir -p third_party && \
    curl -L https://raw.githubusercontent.com/yhirose/cpp-httplib/master/httplib.h \
    -o third_party/httplib.h

# =========================
# prometheus-cpp (build once)
# =========================
RUN git clone --depth 1 https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && \
    cmake -B build -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF && \
    cmake --build build -j$(nproc) && \
    cmake --install build

# =========================
# build binary
# =========================
RUN g++ -O2 -std=c++17 -pthread \
    -Ithird_party \
    ConsoleApplication6.cpp \
    -o prime_checker \
    -lprometheus-cpp-core \
    -lprometheus-cpp-pull


# =========================
# RUNTIME (MINIMAL)
# =========================
FROM ubuntu:22.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# 🔥 minimal runtime ONLY
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/prime_checker /usr/local/bin/prime_checker

# only needed shared libs
COPY --from=builder /usr/local/lib/libprometheus-cpp* /usr/local/lib/

RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/prometheus.conf && ldconfig

EXPOSE 8080
EXPOSE 9090

CMD ["prime_checker"]
