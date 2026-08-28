FROM alpine:3.22 AS builder


ENV TONGSUO_VERSION=8.4.0

ENV ANGIE_VERSION=1.12.1

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    linux-headers \
    git \
    perl \
    make \
    curl \
    cmake \
    pcre2-dev \
    zlib-dev \
    libxml2-dev \
    libxslt-dev

WORKDIR /tmp

# Clone Tongsuo
RUN git clone -b $TONGSUO_VERSION --depth 1 \
    https://github.com/tongsuo-project/tongsuo.git \
    tongsuo-$TONGSUO_VERSION

# Download and extract Angie source
RUN curl -L -o angie-$ANGIE_VERSION.tar.gz \
    https://download.angie.software/files/angie-$ANGIE_VERSION.tar.gz \
    && tar -xzf angie-$ANGIE_VERSION.tar.gz

# Clone third-party dynamic module sources
RUN git clone --recurse-submodules --depth 1 \
        https://github.com/google/ngx_brotli.git \
    && git clone --depth 1 \
        https://github.com/openresty/headers-more-nginx-module.git \
    && git clone --depth 1 \
        https://github.com/openresty/echo-nginx-module.git \
    && git clone --depth 1 \
        https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git \
    && git clone --depth 1 \
        https://github.com/nginx-modules/ngx_cache_purge.git \
    && git clone --depth 1 \
        https://github.com/arut/nginx-dav-ext-module.git \
    && git clone --depth 1 \
        https://github.com/simpl/ngx_devel_kit.git \
    && git clone --depth 1 \
        https://github.com/openresty/set-misc-nginx-module.git

# Build brotli C library (required by ngx_brotli filter module)
RUN cd /tmp/ngx_brotli/deps/brotli \
    && mkdir out && cd out \
    && cmake .. -DCMAKE_BUILD_TYPE=Release \
    && cmake --build . -j$(nproc)

# Configure and build Angie with NTLS support
WORKDIR /tmp/angie-$ANGIE_VERSION

RUN ./configure \
    --prefix=/etc/angie \
    --conf-path=/etc/angie/angie.conf \
    --error-log-path=/var/log/angie/error.log \
    --http-log-path=/var/log/angie/access.log \
    --lock-path=/run/angie.lock \
    --modules-path=/usr/lib/angie/modules \
    --pid-path=/run/angie.pid \
    --sbin-path=/usr/sbin/angie \
    --http-acme-client-path=/var/lib/angie/acme \
    --http-client-body-temp-path=/var/cache/angie/client_temp \
    --http-fastcgi-temp-path=/var/cache/angie/fastcgi_temp \
    --http-proxy-temp-path=/var/cache/angie/proxy_temp \
    --http-scgi-temp-path=/var/cache/angie/scgi_temp \
    --http-uwsgi-temp-path=/var/cache/angie/uwsgi_temp \
    --user=angie \
    --group=angie \
    --with-file-aio \
    --with-http_acme_module \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_acme_module \
    --with-stream_mqtt_preread_module \
    --with-stream_rdp_preread_module \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-threads \
    --with-ld-opt='-Wl,--as-needed,-O1,--sort-common -Wl,-z,pack-relative-relocs' \
    --with-openssl=../tongsuo-$TONGSUO_VERSION \
    --with-openssl-opt=enable-ntls \
    --with-ntls \
    --add-dynamic-module=../ngx_brotli \
    --add-dynamic-module=../headers-more-nginx-module \
    --add-dynamic-module=../echo-nginx-module \
    --add-dynamic-module=../ngx_http_substitutions_filter_module \
    --add-dynamic-module=../ngx_cache_purge \
    --add-dynamic-module=../nginx-dav-ext-module \
    --add-dynamic-module=../ngx_devel_kit \
    --add-dynamic-module=../set-misc-nginx-module \
    && make -j$(nproc) \
    && make install DESTDIR=/tmp/angie-install


FROM alpine:3.22 AS product

LABEL org.opencontainers.image.authors="Release Engineering Team <devops@tech.wbsrv.ru>"
LABEL org.opencontainers.image.authors="Jianlu <jianlu8023@gmail.com>"

# Install runtime dependencies and create angie user
RUN set -x \
    && apk add --no-cache bash ca-certificates curl pcre2 zlib \
    && adduser -D -H -u 101 -s /sbin/nologin angie

# Copy Angie installation from builder
COPY --from=builder /tmp/angie-install/ /

# Tongsuo is statically linked (.a archives), no runtime library copy needed

# Clean up .default files, relocate html, create modules symlink and http.d/stream.d directories
RUN rm -f /etc/angie/*.default \
    && mkdir -p /usr/share/angie/html \
    && mv /etc/angie/html/* /usr/share/angie/html/ \
    && rmdir /etc/angie/html \
    && ln -s /usr/lib/angie/modules /etc/angie/modules \
    && mkdir -p /etc/angie/http.d /etc/angie/stream.d

# Create necessary directories and set permissions
RUN mkdir -p /var/cache/angie /var/log/angie /run/angie \
    && chown -R angie:angie /var/cache/angie /var/log/angie /run/angie /etc/angie /usr/share/angie

# Redirect logs to stdout/stderr
RUN ln -sf /dev/stdout /var/log/angie/access.log \
    && ln -sf /dev/stderr /var/log/angie/error.log

# Copy configuration files
COPY angie.conf /etc/angie/
COPY http.d/default.conf /etc/angie/http.d/
COPY stream.d/example.conf /etc/angie/stream.d/

EXPOSE 80 443

STOPSIGNAL SIGQUIT

CMD ["angie", "-g", "daemon off;"]
