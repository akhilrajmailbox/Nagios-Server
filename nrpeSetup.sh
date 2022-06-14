#!/bin/bash
# this script was written for ubuntu / centos / redhat servers

function depenOn() {
    UNAME=$(uname | tr "[:upper:]" "[:lower:]")
    if [[ "${UNAME}" != "linux" ]] ; then
        echo "Script will work with Linux Platform only..!"
        exit 1
    fi

    DISTRO=""
    until [[ "${DISTRO}" == "ubuntu" ]] || [[ "${DISTRO}" == "centos" ]] || [[ "${DISTRO}" == "redhat" ]] ; do
        read -r -p "Enter Linux Distro :: " DISTRO </dev/tty
        echo "DISTRO can not be empty, choose ubuntu, centos or redhat"
    done
    echo "Configuring nrpe and nagios plugins on ${DISTRO}"

    NAGIOS_SERVER_IP=""
    until [[ ! -z "${NAGIOS_SERVER_IP}" ]] ; do
        read -r -p "Enter Nagios Server IP Address :: " NAGIOS_SERVER_IP </dev/tty
        echo "NAGIOS_SERVER_IP can not be empty"
    done
    echo "Configuring nrpe with Nagios Server IP :: ${NAGIOS_SERVER_IP}, If you want to change it, run this script again"
}

function envSet() {
    depenOn
    if [[ "${DISTRO}" == "ubuntu" ]] ; then
        PLUGIN_DIR="/usr/lib/nagios/plugins"
        PACKAGES_MANAGER="apt-get"
        PACKAGES=(
            "nagios-plugins"
            "nagios-nrpe-server"
            "sed"
            "wget"
            "net-tools"
        )
        NRPE_CMD="/etc/init.d/nagios-nrpe-server restart"
    elif [[ "${DISTRO}" == "centos" ]] ; then
        PLUGIN_DIR="/usr/lib64/nagios/plugins"
        PACKAGES_MANAGER="yum"
        PACKAGES=(
            "epel-release"
            "nagios-plugins-all"
            "nrpe"
            "sed"
            "wget"
            "net-tools"
        )
        NRPE_CMD="systemctl enable nrpe || systemctl restart nrpe || service nrpe restart"
    elif [[ "${DISTRO}" == "redhat" ]] ; then
        PLUGIN_DIR="/usr/lib64/nagios/plugins"
        PACKAGES_MANAGER="yum"
        PACKAGES=(
            "epel-release"
            # dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm 
            # sed -i 's/$releasever/8/g' /etc/yum.repos.d/epel*.repo #(redhat version 8)
            # dnf update
            "nagios-plugins-all"
            #  yum install nagios-plugins-disk nagios-plugins-http nagios-plugins-load nagios-plugins-procs nagios-plugins-tcp nagios-plugins-udp nagios-plugins-users -y
            "nrpe"
            "sed"
            "wget"
            "net-tools"
        )
        NRPE_CMD="systemctl restart nrpe || service nrpe restart"
    else
        echo "Script will work with ubuntu/centos/redhat Platform only..!"
        exit 1
    fi
}

function packageInstall() {
    envSet
    # ${PACKAGES_MANAGER} update -y
    for pkg in ${PACKAGES[@]}; do
        ${PACKAGES_MANAGER} install -y ${pkg}
    done
}

function customPluginsSetup() {
    # my_proc plugin
    wget https://gist.githubusercontent.com/akhilrajmailbox/63a399c3c1714d2cbbbe184c885b67f8/raw/nagios-plugin-my_proc -O ${PLUGIN_DIR}/my_proc
    # my_container plugin
    wget https://gist.githubusercontent.com/akhilrajmailbox/62a525cad966c93524856446582deeab/raw/nagios-plugin-my_container -O ${PLUGIN_DIR}/my_container
    # check_mem plugin
    wget https://gist.githubusercontent.com/akhilrajmailbox/f267e63d64820d29e536edbc14aa30cb/raw/nagios-plugin-check_mem -O ${PLUGIN_DIR}/check_mem
    # all plugins from local directory CustomPlugin
    if [[ -d ./CustomPlugin ]] ; then
        cp -r ./CustomPlugin/* ${PLUGIN_DIR}/
    fi
    chmod -R 755 ${PLUGIN_DIR}/*
}

function nrpeConfig() {
    packageInstall
    customPluginsSetup
    sed -i "s|^server_address=.*|#server_address=|g" /etc/nagios/nrpe.cfg
    sed -i "s|^allowed_hosts=.*|allowed_hosts=127.0.0.1,${NAGIOS_SERVER_IP}|g" /etc/nagios/nrpe.cfg
    sed -i "s|^dont_blame_nrpe=.*|dont_blame_nrpe=1|g" /etc/nagios/nrpe.cfg

    NRPE_REMOTE_CMD=(
        "command[my_disk]=${PLUGIN_DIR}/check_disk \$ARG1\$"
        "command[my_load]=${PLUGIN_DIR}/check_load \$ARG1\$"
        "command[my_procs]=${PLUGIN_DIR}/check_procs \$ARG1\$"
        "command[my_users]=${PLUGIN_DIR}/check_users \$ARG1\$0"
        "command[my_swap]=${PLUGIN_DIR}/check_swap \$ARG1\$"
        "command[my_mem]=${PLUGIN_DIR}/check_mem \$ARG1\$"
        "command[my_http]=${PLUGIN_DIR}/check_http \$ARG1\$"
        "command[my_tcp]=${PLUGIN_DIR}/check_tcp \$ARG1\$"
        "command[my_svc]=${PLUGIN_DIR}/my_proc \$ARG1\$"
        "command[my_container]=${PLUGIN_DIR}/my_container \$ARG1\$ \$ARG2\$"
    )

    if [[ ! -z ${NRPE_REMOTE_CMD} ]] ; then
        ARRAY_SIZE=${#NRPE_REMOTE_CMD[@]}
        ARRAY_START=0
        while [ ${ARRAY_START} -lt ${ARRAY_SIZE} ] ; do
            NRPE_REMOTE_CMD_NAME=`echo ${NRPE_REMOTE_CMD[${ARRAY_START}]} | cut -d"[" -f2 | cut -d"]" -f1`
            if cat /etc/nagios/nrpe.cfg | grep "${NRPE_REMOTE_CMD_NAME}" >/dev/null; then
                echo "The nrpe command : ${NRPE_REMOTE_CMD_NAME}, already available in this machines"
            else
                echo "Configuring the nrpe command : ${NRPE_REMOTE_CMD_NAME}"
                echo ${NRPE_REMOTE_CMD[${ARRAY_START}]} >> /etc/nagios/nrpe.cfg
            fi
            ARRAY_START=`expr ${ARRAY_START} + 1`
        done
    else
        echo "NRPE_REMOTE_CMD is empty"
    fi
}

function depensConf() {
    usermod -aG docker nrpe
}

function startNrpe() {
    nrpeConfig \
    && depensConf \
    && ${NRPE_CMD} \
    && sleep 5 \
    && netstat -tulpn | grep 5666
}



startNrpe