FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    TONGSUO_VERSION=8.4.0

RUN sed -i "s/archive.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list && \
    sed -i "s/security.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list && \
    apt update && \
    apt install -y --no-install-recommends build-essential \
    git \
    make \
    perl \
    ca-certificates \
    libssl-dev \
    zlib1g-dev

WORKDIR /usr/local/src
RUN git clone -b $TONGSUO_VERSION --depth=1 https://github.com/tongsuo-project/tongsuo.git tongsuo

WORKDIR /usr/local/src/tongsuo

RUN ./config --prefix=/usr/local/tongsuo \
    --openssldir=/usr/local/tongsuo/ssl \
    -Wl,-rpath,/usr/local/tongsuo/lib \
    enable-ec_elgamal \
    enable-ntls \
    enable-sm2 \
    enable-sm3  \
    enable-sm4 && \
    make -j$(nproc) && \
    make install && \
    echo "/usr/local/tongsuo/lib64" | tee -a /etc/ld.so.conf.d/tongsuo.conf && \
    echo "/usr/local/tongsuo/lib" | tee -a /etc/ld.so.conf.d/tongsuo.conf && \
    ldconfig

ENV PATH=/usr/local/tongsuo/bin:$PATH

CMD ["tongsuo","version","-a"]
