FROM ubuntu:22.04

LABEL maintainer="Ruben Heradio <rheradio@issi.uned.es>"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    g++ \
    cmake \
    make \
    zlib1g-dev \
    libgmp-dev \
    libmpfr-dev \
    r-base \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /uvl2dimacs

COPY . .

RUN rm -rf antlr/build/ build/ backbone_solver/bin/ backbone_solver/src/minisat/build/ \
    tests/sharpsat-td/bin/ tests/sharpsat-td/build/ \
    && find backbone_solver/src -name "*.o" -delete \
    && make

ENTRYPOINT ["./build/uvl2dimacs"]
