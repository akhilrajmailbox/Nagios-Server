#!/bin/bash

function setFileEnv() {
    local var="${1}"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo >&2 "error: both ${var} and ${fileVar} are set..! task aborting"
        exit 1
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        echo "DEVOPS_INFO : Setting ${var} from ${var}"
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        echo "DEVOPS_INFO : Setting ${var} from ${fileVar}"
        val="$(< "${!fileVar}")"
    fi
    export "${var}"="${val}"
    unset "${fileVar}"
}


setFileEnv ${1} ${2}