FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    TONGSUO_VERSION=8.4.0

RUN sed -i "s/archive.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list && \
    sed -i "s/security.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list && \
    apt update && \
    apt install -y --no-install-recommends \
    build-essential git make perl \
    ca-certificates \
    libssl-dev zlib1g-dev \
    zip unzip

WORKDIR /usr/local/src
RUN git clone -b $TONGSUO_VERSION --depth=1 https://github.com/tongsuo-project/tongsuo.git tongsuo-$TONGSUO_VERSION

WORKDIR /usr/local/src/tongsuo-$TONGSUO_VERSION

# --prefix 指定铜锁安装目录
# --openssldir 指定配置文件和证书文件的存放目录
# enable-xx 启用
# -no-shared 不生成.so文件 只生成.a文件
# -fPIC 生成位置无关代码 通常是编译动态库的要求
# -no-shared -fPIC 建议一起使用
RUN ./config --prefix=/usr/local/tongsuo \
    --openssldir=/usr/local/tongsuo/ssl \
    -Wl,-rpath,/usr/local/tongsuo/lib \
    enable-ec_elgamal \
    enable-ntls \
    enable-sm2 \
    enable-sm3  \
    enable-sm4 \
    -fPIC \
    -no-shared && \
    make -j$(nproc) && \
    make install && \
    echo "/usr/local/tongsuo/lib" | tee /etc/ld.so.conf.d/tongsuo.conf && \
    echo "/usr/local/tongsuo/lib64" | tee -a /etc/ld.so.conf.d/tongsuo.conf && \
    ldconfig && \
    make clean

ENV PATH=/usr/local/tongsuo/bin:$PATH

WORKDIR /workspace

CMD ["tongsuo","version","-a"]
