FROM debian:jessie

# Keep upstart from complaining
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# import Lenny key
# RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4D270D06F42584E6

# Pin PHP to version 5.2 (from Lenny)
# ADD ./apt-lenny.list /etc/apt/sources.list.d/apt-lenny.list
# ADD ./lenny-php52 /etc/apt/preferences.d/lenny-php52

# install the PHP extensions we need


# RUN apt-get update && apt-get install -f -y curl sendmail vim-common vim-runtime libpng12-dev libjpeg-dev wget unzip nginx python-setuptools mysql-client git-core libxml2 gcc libxml2-dev libevent-dev patch libcurl4-openssl-dev libbz2-dev libjpeg-dev libpng12-dev libxpm-dev libfreetype6-dev libmcrypt-dev libmhash-dev libmysqlclient-dev libpspell-dev libexpat1-dev libxslt1-dev make && rm -rf /var/lib/apt/lists/* 

RUN apt-get update \
    && apt-get install -y \
    	nginx \
    	sendmail \
    	curl \
        autoconf2.13 \
        libbz2-dev \
        libcurl4-openssl-dev \
        libltdl-dev \
        libmcrypt-dev \
        libevent-dev \
        libmhash-dev \
        libmysqlclient-dev \
        libssl-dev \
        libpcre3-dev \
        libpng12-dev \
        libxml2-dev \
        pkg-config \
        make \
        patch \
        xmlstarlet \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ADD src/ /tmp
# WORKDIR /tmp
RUN gunzip /tmp/*.gz && tar xf /tmp/php-5.2.16.tar -C /tmp
WORKDIR /tmp/php-5.2.16

# Apply patches
RUN patch -p1 -i ../php-5.2.16-fpm-0.5.14.diff && \
    patch -p1 -i ../suhosin-patch-5.2.16-0.9.7.patch && \
    patch -p0 -i ../libxml29_compat.patch

# Configure
RUN ./buildconf --force

RUN chmod a+x ./libevent/configure ./libevent/depcomp ./libevent/install-sh ./libevent/missing && ./configure \
    --enable-fastcgi \
    --enable-fpm \
    --enable-mbstring \
    --enable-sockets \
    --with-config-file-path=/etc/php5 \
    --with-curl \
    --with-fpm-conf=/etc/php5/php-fpm.conf \
    --with-fpm-log=/var/log/php/php_errors.log \
    --with-fpm-pid=/var/run/php/php-fpm.pid \
    --with-gd \
    --with-gettext \
    --with-libdir=lib/x86_64-linux-gnu \
    --with-mcrypt \
    --with-mhash \
    --with-mysql \
    --with-mysql-sock \
    --with-mysqli \
    --with-openssl \
    --with-pcre-regex \
    --with-png-dir \
    --with-zlib \
    --without-sqlite

# Install
RUN make && make install

# Uninstall autoconf2.13 after compilation.
RUN apt-get remove -y autoconf2.13

# Clean up
RUN rm -rf /tmp/* /var/tmp/*

# Get out of /tmp
WORKDIR /

# nginx config
RUN sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf
RUN sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf
RUN sed -i -e"s/user www-data/user root/" /etc/nginx/nginx.conf
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

# php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf
RUN sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php5/fpm/pool.d/www.conf
RUN sed -i -e "s/user\s*=\s*www-data/user = root/g" /etc/php5/fpm/pool.d/www.conf
RUN sed -i -e "s/group\s*=\s*www-data/group = root/g" /etc/php5/fpm/pool.d/www.conf
RUN sed -i -e "s/listen.owner\s*=\s*www-data/listen.owner = root/g" /etc/php5/fpm/pool.d/www.conf
RUN find /etc/php5/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# nginx site conf
ADD ./nginx-site.conf /etc/nginx/sites-available/default

# Supervisor Config
RUN /usr/bin/easy_install supervisor
RUN /usr/bin/easy_install supervisor-stdout
ADD ./supervisord.conf /etc/supervisord.conf

# install wp-cli
RUN wget https://github.com/wp-cli/builds/raw/gh-pages/deb/php-wpcli_0.17.1_all.deb
RUN dpkg -i php-wpcli_0.17.1_all.deb

# install wp-cli server command
RUN mkdir -p ~/.wp-cli/commands
RUN git clone https://github.com/wp-cli/server-command.git ~/.wp-cli/commands/server

VOLUME /var/www/html

ENV WORDPRESS_VERSION 4.2.1
ENV WORDPRESS_UPSTREAM_VERSION 4.2.1
ENV WORDPRESS_SHA1 c93a39be9911591b19a94743014be3585df0512f

# upstream tarballs include ./wordpress/ so this gives us /usr/src/wordpress
RUN curl -o wordpress.tar.gz -SL https://wordpress.org/wordpress-${WORDPRESS_UPSTREAM_VERSION}.tar.gz \
	&& echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c - \
	&& tar -xzf wordpress.tar.gz -C /usr/src/ \
	&& rm wordpress.tar.gz

ADD ./docker-entrypoint.sh /entrypoint.sh
ADD ./config.yml /root/.wp-cli/

WORKDIR /var/www/html

# grr, ENTRYPOINT resets CMD now
ENTRYPOINT ["/entrypoint.sh"]

# start all the services
CMD ["/usr/local/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]