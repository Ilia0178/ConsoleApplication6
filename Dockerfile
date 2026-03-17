
# --------------------------------------------------------------------
# ЭТАП 1
# --------------------------------------------------------------------
FROM gcc:latest AS builder

# Рабочая директория
WORKDIR /app

# Копируем исходный код и Makefile
COPY . .

RUN apt-get update && apt-get install -y build-essential dpkg-dev

# Запуск сборки
RUN make all 
# --------------------------------------------------------------------
# ЭТАП 2
# --------------------------------------------------------------------
FROM debian:bookworm-slim

WORKDIR /usr/bin/

COPY --from=builder /app/prime-checker .
ENTRYPOINT ["prime-checker"]