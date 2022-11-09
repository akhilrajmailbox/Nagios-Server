FROM ubuntu:14.04

RUN bash -c 'debconf-set-selections <<< "postfix postfix/mailname string nagios.local"'
RUN bash -c 'debconf-set-selections <<< "postfix postfix/main_mailer_type string Internet Site"'
RUN apt-get update && apt-get upgrade -y && apt-get install -y apache2 sudo vim net-tools curl \
            dnsutils wget build-essential libgd2-xpm-dev openssl libssl-dev xinetd \
            apache2-utils unzip postfix php5 libapache2-mod-php5 php5-mcrypt php5-cli mailutils
RUN useradd nagios && groupadd nagcmd && usermod -a -G nagcmd nagios

## Installing and Configuring Nagios Server
WORKDIR /opt/
# RUN curl -L -O https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.3.2.tar.gz
# RUN tar xvf nagios-*.tar.gz && rm -rf nagios-*.tar.gz && mv /opt/nagios-* /opt/nagios
ADD Resources/nagios-4.3.2.tar.gz /opt/
RUN mv /opt/nagios-* /opt/nagios
WORKDIR /opt/nagios
RUN ./configure --with-nagios-group=nagios --with-command-group=nagcmd
RUN make all
RUN make install
RUN make install-commandmode
RUN make install-init
RUN make install-config
RUN /usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-available/nagios.conf
RUN usermod -G nagcmd www-data

## Installing all nagios plugins
WORKDIR /opt/
# RUN curl -L -O http://nagios-plugins.org/download/nagios-plugins-2.2.1.tar.gz
# RUN tar xvf /opt/nagios-plugins-*.tar.gz && rm -rf nagios-plugins-*.tar.gz && mv /opt/nagios-plugins-* /opt/nagios-plugins
ADD Resources/nagios-plugins-2.2.1.tar.gz /opt/
RUN mv /opt/nagios-plugins-* /opt/nagios-plugins
WORKDIR /opt/nagios-plugins
RUN ./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-openssl
RUN make
RUN make install

## Configuring nrpe plugin for nagios
WORKDIR /opt/
# RUN curl -L -O http://downloads.sourceforge.net/project/nagios/nrpe-2.x/nrpe-2.15/nrpe-2.15.tar.gz
# RUN tar xvf /opt/nrpe-*.tar.gz && rm -rf nrpe-*.tar.gz && mv /opt/nrpe-* /opt/nrpe
ADD Resources/nrpe-2.15.tar.gz /opt/
RUN mv /opt/nrpe-* /opt/nrpe
WORKDIR /opt/nrpe
RUN ./configure --enable-command-args --with-nagios-user=nagios --with-nagios-group=nagios --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu
RUN make all
RUN make install
RUN make install-xinetd
RUN make install-daemon-config

## Customisation of nagios server
WORKDIR /opt/ 
# RUN curl -L -O http://sourceforge.net/projects/arana-nagios/files/arana_style-1.0for-Nagios3x-ENG.zip
COPY Resources/arana_style-1.0for-Nagios3x-ENG.zip /opt/
RUN unzip arana_style-*.zip && cp -r arana_style/* /usr/local/nagios/share/ && rm -rf arana_style*
COPY nath_status.php /usr/local/nagios/share/nath_status.php

EXPOSE 25 465 587 80 5666

## Customising the nagios configuration location
RUN sed -i "s|#cfg_dir=/usr/local/nagios/etc/servers|cfg_dir=/usr/local/nagios/etc/servers|g" /usr/local/nagios/etc/nagios.cfg
RUN mkdir /usr/local/nagios/etc/servers
RUN mv /etc/xinetd.d/nrpe /etc/xinetd.d/nrpe-bak
RUN mv /usr/local/nagios/etc/objects/commands.cfg /usr/local/nagios/etc/objects/commands.cfg-bak

## nagios configurations
COPY ConfigTemplates/template.cfg /usr/local/nagios/etc/servers/template.cfg
COPY ConfigTemplates/commands.cfg /usr/local/nagios/etc/objects/commands.cfg

## Configuring custom templates and plugins for nagios plugins
COPY ConfigTemplates/contacts.cfg /usr/local/nagios/etc/servers/monitor/contacts.cfg
# COPY CustomPlugin/check_mem /usr/local/nagios/libexec/check_mem
RUN chmod a+x /usr/local/nagios/libexec/*

ENV USER_PASSWORD "MyroUserCreds"
ENV SMTP_SERVER "smtp.gmail.com"
ENV SMTP_PORT "587"
ENV SMTP_USERNAME ""
ENV SMTP_PASSWORD ""
ENV NAGIOS_MAIL_SENDER "PagerDuty <mymail@gmail.com>"
ENV LOCAL_MONITOR "N"

COPY entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]