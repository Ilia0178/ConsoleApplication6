FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y dpkg && \
    rm -rf /var/lib/apt/lists/*

COPY *.deb /tmp/prime_checker.deb

RUN dpkg -i /tmp/prime_checker.deb && \
    rm /tmp/prime_checker.deb

ENTRYPOINT ["prime_checker"]