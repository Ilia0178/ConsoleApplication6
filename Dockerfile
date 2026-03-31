FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y build-essential cmake

WORKDIR /app
COPY . .

RUN g++ -Wall -Wextra -std=c++17 -O2 ConsoleApplication6.cpp -o prime_checker

FROM ubuntu:22.04

RUN apt-get update && apt-get install -y libstdc++6 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/prime_checker /usr/bin/prime_checker
RUN chmod +x /usr/bin/prime_checker

ENTRYPOINT ["/usr/bin/prime_checker"]