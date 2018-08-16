FROM nginx:alpine

LABEL maintainer="Dalitso / Ville Nupponen <docker@dalitso.fi>"

ENV WP_VERSION 4.9.8

RUN apk update \
	&& apk --no-cache add wget bash php7 php7-fpm php7-mysqli php7-zip php7-imagick exim

RUN addgroup -S www-data \
	&& adduser -SDh /var/www www-data www-data \
	&& mkdir -p /var/www/wp \
	&& wget https://wordpress.org/wordpress-$WP_VERSION.tar.gz -O wp.tar.gz \
	&& tar -C /var/www/wp -xf wp.tar.gz --strip 1 \
	&& rm wp.tar.gz \
        && rm -rf /var/www/wp/wp-content \
	&& chown -R www-data:www-data /var/www/wp

ADD ./nginx-default.conf /etc/nginx/conf.d/default.conf
RUN sed -i -e 's/nobody/www-data/g' /etc/php7/php-fpm.d/www.conf

COPY ./docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

VOLUME /var/www/wp/wp-content
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
