FROM ubuntu:22.04
MAINTAINER Akhil Raj

# Basic packages and configuration
RUN bash -c 'debconf-set-selections <<< "postfix postfix/mailname string nagios.local"'
RUN bash -c 'debconf-set-selections <<< "postfix postfix/main_mailer_type string Internet Site"'
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential apache2 php openssl perl make mailutils libmcrypt-dev iputils-ping \
    php-gd libgd-dev libapache2-mod-php libperl-dev libssl-dev daemon wget apache2-utils unzip autoconf automake gcc libc6 net-tools dnsutils
RUN useradd nagios \
    && groupadd nagcmd \
    && usermod -a -G nagcmd nagios \
    && usermod -a -G nagcmd www-data

## Installing and Configuring Nagios Server
WORKDIR /opt/
# RUN curl -L -O https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.4.6.tar.gz
COPY Resources/nagios-4.4.6.tar.gz /opt/
RUN tar xvf nagios-*.tar.gz \
    && rm -rf nagios-*.tar.gz \
    && mv /opt/nagios-* /opt/nagios
WORKDIR /opt/nagios
RUN ./configure --with-nagios-group=nagios --with-command-group=nagcmd --with-httpd_conf=/etc/apache2/sites-enabled/ \
    && make all \
    && make install \
    && make install-init \
    && make install-config \
    && make install-commandmode \
    && make install-webconf

## Installing all nagios plugins
WORKDIR /opt/
# RUN curl -L -O https://nagios-plugins.org/download/nagios-plugins-2.3.3.tar.gz
COPY Resources/nagios-plugins-2.3.3.tar.gz /opt/
RUN tar xvf /opt/nagios-plugins-*.tar.gz \
    && rm -rf nagios-plugins-*.tar.gz \
    && mv /opt/nagios-plugins-* /opt/nagios-plugins
WORKDIR /opt/nagios-plugins
RUN ./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-openssl \
    && make \
    && make install

## Configuring nrpe plugin for nagios
WORKDIR /opt/
# RUN wget --no-check-certificate -O nrpe-4.1.0.tar.gz https://github.com/NagiosEnterprises/nrpe/archive/nrpe-4.1.0.tar.gz
COPY Resources/nrpe-4.1.0.tar.gz /opt/
RUN tar xvf /opt/nrpe-*.tar.gz \
    && rm -rf nrpe-*.tar.gz \
    && mv /opt/nrpe-* /opt/nrpe
WORKDIR /opt/nrpe
# RUN ./configure --enable-command-args --with-ssl-lib=/usr/lib/x86_64-linux-gnu/ \
RUN ./configure --enable-command-args --with-nagios-user=nagios --with-nagios-group=nagios --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu \
    && make all \
    && make install

## Customisation of nagios server
WORKDIR /opt/ 
# RUN curl -L -O http://sourceforge.net/projects/arana-nagios/files/arana_style-1.0for-Nagios3x-ENG.zip
COPY Resources/arana_style-1.0for-Nagios3x-ENG.zip /opt/
RUN unzip arana_style-*.zip \
    && cp -r arana_style/* /usr/local/nagios/share/ \
    && rm -rf arana_style*
COPY nath_status.php /usr/local/nagios/share/nath_status.php

## nagios configurations
WORKDIR /usr/local/nagios/etc/servers
RUN sed -i "s|#cfg_dir=/usr/local/nagios/etc/servers|cfg_dir=/usr/local/nagios/etc/servers|g" /usr/local/nagios/etc/nagios.cfg
COPY ConfigTemplates/template.cfg /usr/local/nagios/etc/servers/template.cfg
COPY ConfigTemplates/commands.cfg /usr/local/nagios/etc/objects/commands.cfg

## Configuring custom templates and plugins for nagios plugins
COPY ConfigTemplates/contacts.cfg /usr/local/nagios/etc/servers/monitor/contacts.cfg

WORKDIR /run/secrets
RUN echo "MyroUserCreds" > /run/secrets/CUSTOM_USER_PASSWORD

ENV USER_PASSWORD=""
ENV USER_PASSWORD_FILE="/run/secrets/CUSTOM_USER_PASSWORD"
ENV SMTP_SERVER="smtp.gmail.com"
ENV SMTP_PORT="587"
ENV SMTP_USERNAME=""
ENV SMTP_PASSWORD=""
ENV SMTP_PASSWORD_FILE=""
ENV NAGIOS_MAIL_SENDER="PagerDuty <mymail@gmail.com>"
ENV LOCAL_MONITOR="N"

COPY entrypoint.sh /
COPY envFromFile.sh /
RUN chmod a+x /envFromFile.sh /entrypoint.sh

EXPOSE 25 465 587 80 5666
WORKDIR /usr/local/nagios
ENTRYPOINT [ "/entrypoint.sh" ]