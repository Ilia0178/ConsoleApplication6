# СТАДИЯ 1: Builder
FROM ubuntu:22.04 AS builder

# Устанавливаем все для сборки
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git libcurl4-openssl-dev zlib1g-dev \
    libssl-dev ca-certificates && rm -rf /var/lib/apt/lists/*

# Копируем исходный код в контейнер
COPY . /src
WORKDIR /src

# Собираем бинарник внутри
RUN mkdir build && cd build && \
    cmake .. && make -j$(nproc)

# СТАДИЯ 2: Runtime
FROM ubuntu:22.04

# Устанавливаем только runtime зависимости
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4 libssl3 ca-certificates && rm -rf /var/lib/apt/lists/*

# Копируем только готовый бинарник из стадии builder
COPY --from=builder /src/build/prime_checker /usr/local/bin/prime_checker

# Делаем его исполняемым
RUN chmod +x /usr/local/bin/prime_checker

EXPOSE 8080 9090

CMD ["/usr/local/bin/prime_checker"]