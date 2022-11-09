#!/bin/bash
A=$(tput sgr0)
export TERM=xterm
echo ""
echo ""
echo -e '\E[33m'"----------------------------------- $A"
echo -e '\E[33m'"|   optional docker variable      | $A"
echo -e '\E[33m'"----------------------------------- $A"
echo -e '\E[33m'"----------------------------------- $A"
echo -e '\E[33m'"|    1)  LOCAL_MONITOR            | $A"
echo -e '\E[33m'"----------------------------------- $A"
echo ""
echo -e '\E[32m'"###################################### $A"
echo -e '\E[32m'"###          LOCAL_MONITOR         ### $A"
echo -e '\E[32m'"###################################### $A"
echo -e '\E[33m'"If you want the nagios server to monitor its own host (the container itself [localhost portion in ui]), use this environment variable, value should be 'Y' $A"
echo -e '\E[33m'"If you don't want to monitor the the container itself, Do not use this Environment variable $A"
echo ""
echo -e '\E[33m'"If you don't want localhost monitoring, It will shows some error because of the empty host-list, $A"
echo -e '\E[33m'"you can add new '<<name>>.cfg' file which have hosts and services under '/usr/local/nagios/etc/servers' and reload the service 'service nagios reload' or mount the location to the docker machine with the cfg file $A"
echo ""
echo "Configuring........"
sleep 5

source /envFromFile.sh SMTP_USERNAME
source /envFromFile.sh SMTP_PASSWORD
source /envFromFile.sh NAGIOS_USERNAME
source /envFromFile.sh NAGIOS_PASSWORD


##########################################
function setAdminCred() {
cat << EOF > /usr/local/bin/adminpass
#!/bin/bash
base64 /tmp/DeploymentTime.txt
EOF
chmod a+x /usr/local/bin/adminpass
}

##########################################
function serviceConfig() {
    echo "configuring nagios"
    if [[ ! -f /usr/local/nagios/etc/htpasswd.users ]] ; then
        if [[ "${DeploymentTime}" = "" ]] ; then
            export DeploymentTime=$(TZ=Asia/Calcutta date +%F--%H-%M-%S--%Z)
            echo ""
            echo "ADMIN_USERNAME : nagiosadmin"
            echo "ADMIN_PASSWORD : you have to run the command : adminpass in the nagios container to get the admin password"
            echo ""
        else
            sleep 1
        fi

        echo "${DeploymentTime}" > /tmp/DeploymentTime.txt
        ADMIN_PASSWORD=$(base64 /tmp/DeploymentTime.txt)
        htpasswd -b -c /usr/local/nagios/etc/htpasswd.users nagiosadmin ${ADMIN_PASSWORD}
        unset ADMIN_PASSWORD
        setAdminCred

        if [[ ! "${NAGIOS_PASSWORD}" = "" ]] ; then
            if [[ ! ${NAGIOS_USERNAME} == "" ]] ; then
                export NAGIOS_USERNAME="nagiosuser"
            fi
            htpasswd -b /usr/local/nagios/etc/htpasswd.users ${NAGIOS_USERNAME} ${NAGIOS_PASSWORD}
            echo "authorized_for_read_only=${NAGIOS_USERNAME}" >> /usr/local/nagios/etc/cgi.cfg
        fi
    fi

    if [[ ${LOCAL_MONITOR} == "y" || ${LOCAL_MONITOR} == "Y" ]] ; then
        echo "Nagios will monitor localhost also"
    else
        sed -i "s|cfg_file=/usr/local/nagios/etc/objects/localhost.cfg|#cfg_file=/usr/local/nagios/etc/objects/localhost.cfg|g" /usr/local/nagios/etc/nagios.cfg
    fi

    if [[ ! -z ${SMTP_SERVER} ]] && [[ ! -z ${SMTP_PORT} ]] && [[ ! -z ${SMTP_USERNAME} ]] && [[ ! -z ${SMTP_PASSWORD} ]] ; then
        echo "SMTP Server Details available.....  Configuing SMTP Relay"
        postconf -e "relayhost = [${SMTP_SERVER}]:${SMTP_PORT}" \
            "smtp_sasl_auth_enable = yes" \
            "smtp_sasl_security_options = noanonymous" \
            "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" \
            "smtp_use_tls = yes" \
            "smtp_tls_security_level = encrypt" \
            "smtp_tls_note_starttls_offer = yes" \
            "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"
        echo "[${SMTP_SERVER}]:${SMTP_PORT} ${SMTP_USERNAME}:${SMTP_PASSWORD}" > /etc/postfix/sasl_passwd
        postmap /etc/postfix/sasl_passwd

        chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
        chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
    fi

    if [[ -z ${NAGIOS_MAIL_SENDER} ]] ; then
        NAGIOS_MAIL_SENDER=nagios.local
    fi
    
    sed -i "s|NAGIOS_MAIL_SENDER|${NAGIOS_MAIL_SENDER}|g" /usr/local/nagios/etc/objects/commands.cfg
    postconf -e myhostname="`hostname -f`"
    postconf -e mydestination="`hostname -f`, localhost.localdomain, localhost"
    echo "`hostname -f`" > /etc/mailname
    sed -i "s|^result_limit=.*|result_limit=0|g" /usr/local/nagios/etc/cgi.cfg
    chown -R nagios:nagios /usr/local/nagios/etc/servers
}


##########################################
function customConfig() {
    serviceConfig

    if [[ -d /tmp/MonitorCfg ]] ; then
        echo "MonitorCfg found, over writing the monitoring configuration"
        rm -rf /usr/local/nagios/etc/servers/monitor/*
        cp -r /tmp/MonitorCfg/* /usr/local/nagios/etc/servers/monitor/
        chown -R nagios:nagios /usr/local/nagios/etc/servers
    fi

    if [[ -d /tmp/CustomPlugin ]] ; then
        echo "CustomPlugin found, adding it to the libs"
        pluginList=$(ls /tmp/CustomPlugin)
        for pluginName in ${pluginList[*]} ; do
            rm -rf /usr/local/nagios/libexec/${pluginName}
            cp -r /tmp/CustomPlugin/${pluginName} /usr/local/nagios/libexec/${pluginName}
        done
        chmod a+x /usr/local/nagios/libexec/*
    fi
}

##########################################
function serviceStart() {
    customConfig
    a2enmod rewrite
    a2enmod cgi
    service nagios restart & wait
    service postfix restart & wait
    ps -ef | grep -v grep | grep -i apache2 | awk '{print $2}' | xargs kill -9
    apachectl -D FOREGROUND
}



serviceStart