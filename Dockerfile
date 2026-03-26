# ===================================================================
# 1 Сборка приложения
# ===================================================================
FROM ubuntu:22.04 AS builder

RUN apt-get update && \
    apt-get install -y build-essential && \
    rm -rf /var/lib/apt/lists/*

COPY . /app
WORKDIR /app

RUN make build

# ===================================================================
# 2 Создание DEB пакета
# ===================================================================
FROM ubuntu:22.04 AS deb_package

RUN apt-get update && \
    apt-get install -y dpkg-dev make && \
    rm -rf /var/lib/apt/lists/*

COPY . /app
WORKDIR /app

COPY --from=builder /app/prime_checker /app/prime_checker

RUN make package 

# ===================================================================
# 3 Финальный образ 
# ===================================================================
FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y dpkg-dev && \
    rm -rf /var/lib/apt/lists/*

COPY --from=deb_package /app/*.deb /app/

RUN dpkg -i /app/*.deb && \
    rm /app/*.deb && \
    rm -rf /app 
ENTRYPOINT ["prime_checker"]