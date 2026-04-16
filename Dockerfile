# СТАДИЯ 1: Builder
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git libcurl4-openssl-dev zlib1g-dev \
    libssl-dev ca-certificates && rm -rf /var/lib/apt/lists/*

RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && make install && ldconfig

# СТАДИЯ 2: Runtime
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4 libssl3 ca-certificates && rm -rf /var/lib/apt/lists/*

# Копируем библиотеки из builder
COPY --from=builder /usr/local/lib /usr/local/lib
RUN ldconfig

# Копируем бинарник, который мы скачали в CI
# Убедитесь, что файл prime_checker реально лежит рядом с Dockerfile
COPY prime_checker /usr/local/bin/prime_checker
RUN chmod +x /usr/local/bin/prime_checker

# Жестко задаем путь для поиска библиотек
ENV LD_LIBRARY_PATH=/usr/local/lib

EXPOSE 8080 9090

CMD ["/usr/local/bin/prime_checker"]