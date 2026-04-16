# =========================================================
# СТАДИЯ 1: Builder (Сборка зависимостей и приложения)
# =========================================================
FROM ubuntu:22.04 AS builder

# Установка всех инструментов для сборки
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Сборка prometheus-cpp
# (Эта часть закэшируется и будет пропускаться при изменении только кода приложения)
RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp.git /tmp/prom && \
    cd /tmp/prom && mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=OFF -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# =========================================================
# СТАДИЯ 2: Runtime (Финальный образ)
# =========================================================
FROM ubuntu:22.04

# Установка только необходимых runtime-библиотек
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4 \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Копируем библиотеки prometheus из стадии builder
COPY --from=builder /usr/local/lib /usr/local/lib
# Копируем заголовочные файлы если нужно (опционально) или просто обновляем кэш библиотек
RUN ldconfig

# Копируем скомпилированный бинарник (из артефакта, который вы скачали в CI)
# ВАЖНО: убедитесь, что имя файла совпадает
COPY prime_checker /usr/local/bin/prime_checker

# Настройка путей для библиотек
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Открываем порты
EXPOSE 8080 9090

# Запуск приложения
CMD ["/usr/local/bin/prime_checker"]