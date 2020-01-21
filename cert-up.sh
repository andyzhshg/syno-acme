#!/bin/bash

# path of this script
BASE_ROOT=$(cd "$(dirname "$0")";pwd)
# date time
DATE_TIME=`date +%Y%m%d%H%M%S`
# base crt path
CRT_BASE_PATH="/usr/syno/etc/certificate"
PKG_CRT_BASE_PATH="/usr/local/etc/certificate"
#CRT_BASE_PATH="/Users/carl/Downloads/certificate"
ACME_BIN_PATH=${BASE_ROOT}/acme.sh
TEMP_PATH=${BASE_ROOT}/temp

backupCrt () {
  echo 'begin backupCrt'
  BACKUP_PATH=${BASE_ROOT}/backup/${DATE_TIME}
  mkdir -p ${BACKUP_PATH}
  cp -r ${CRT_BASE_PATH} ${BACKUP_PATH}
  cp -r ${PKG_CRT_BASE_PATH} ${BACKUP_PATH}/package_cert
  echo ${BACKUP_PATH} > ${BASE_ROOT}/backup/latest
  echo 'done backupCrt'
  return 0
}

installAcme () {
  echo 'begin installAcme'
  mkdir -p ${TEMP_PATH}
  cd ${TEMP_PATH}
  echo 'begin downloading acme.sh tool...'
  ACME_SH_ADDRESS=`curl -L https://raw.githubusercontent.com/andyzhshg/syno-acme/master/acme.sh.address`
  SRC_TAR_NAME=acme.sh.tar.gz
  curl -L -o ${SRC_TAR_NAME} ${ACME_SH_ADDRESS}
  SRC_NAME=`tar -tzf ${SRC_TAR_NAME} | head -1 | cut -f1 -d"/"`
  tar zxvf ${SRC_TAR_NAME}
  echo 'begin installing acme.sh tool...'
  cd ${SRC_NAME}
  ./acme.sh --install --nocron --home ${ACME_BIN_PATH}
  echo 'done installAcme'
  rm -rf ${TEMP_PATH}
  return 0
}

generateCrt () {
  echo 'begin generateCrt'
  cd ${BASE_ROOT}
  source config
  echo 'begin updating default cert by acme.sh tool'
  source ${ACME_BIN_PATH}/acme.sh.env
  ${ACME_BIN_PATH}/acme.sh --force --log --issue --dns ${DNS} --dnssleep ${DNS_SLEEP} -d "${DOMAIN}" -d "*.${DOMAIN}"
  ${ACME_BIN_PATH}/acme.sh --force --installcert -d ${DOMAIN} -d *.${DOMAIN} \
    --cert-file ${CRT_PATH}/cert.pem \
    --key-file ${CRT_PATH}/privkey.pem \
    --fullchain-file ${CRT_PATH}/fullchain.pem

  if [ -s "${CRT_PATH}/cert.pem" ]; then
    echo 'done generateCrt'
    return 0
  else
    echo '[ERR] fail to generateCrt'
    echo "begin revert"
    revertCrt
    exit 1;
  fi
}

updateService () {
  echo 'begin updateService'
  echo 'cp cert path to des'
  /bin/python2 ${BASE_ROOT}/crt_cp.py ${CRT_PATH_NAME}
  echo 'done updateService'
}

reloadWebService () {
  echo 'begin reloadWebService'
  echo 'reloading new cert...'
  /usr/syno/etc/rc.sysv/nginx.sh reload
  echo 'relading Apache 2.2'
  stop pkg-apache22
  start pkg-apache22
  reload pkg-apache22
  echo 'done reloadWebService'  
}

revertCrt () {
  echo 'begin revertCrt'
  BACKUP_PATH=${BASE_ROOT}/backup/$1
  if [ -z "$1" ]; then
    BACKUP_PATH=`cat ${BASE_ROOT}/backup/latest`
  fi
  if [ ! -d "${BACKUP_PATH}" ]; then
    echo "[ERR] backup path: ${BACKUP_PATH} not found."
    return 1
  fi
  echo "${BACKUP_PATH}/certificate ${CRT_BASE_PATH}"
  cp -rf ${BACKUP_PATH}/certificate/* ${CRT_BASE_PATH}
  echo "${BACKUP_PATH}/package_cert ${PKG_CRT_BASE_PATH}"
  cp -rf ${BACKUP_PATH}/package_cert/* ${PKG_CRT_BASE_PATH}
  reloadWebService
  echo 'done revertCrt'
}

updateCrt () {
  echo '------ begin updateCrt ------'
  backupCrt
  installAcme
  generateCrt
  updateService
  reloadWebService
  echo '------ end updateCrt ------'
}

case "$1" in
  update)
    echo "begin update cert"
    
    # set target
    if [[ -n "$2" ]] ; then
      CRT_PATH_NAME="$2"
    else
      CRT_PATH_NAME=`cat ${CRT_BASE_PATH}/_archive/DEFAULT`
    fi
    CRT_PATH=${CRT_BASE_PATH}/_archive/${CRT_PATH_NAME}
    
    # set domain
    if [[ -n "$3" ]] ; then
      DOMAIN="$3"
    fi
    
    # set DNS
    if [[ -n "$4" ]] ; then
      DNS="$4"
    fi
    
    updateCrt
    ;;

  revert)
    echo "begin revert"
      revertCrt $2
      ;;

  show)
    cat ${CRT_BASE_PATH}/_archive/INFO
      ;;

    *)
        echo "Usage:"
        echo -e "\t$0 update [cert_id] [domain] [dns]"
        echo -e "\t$0 revert [date_time]"
        echo -e "\t$0 show"
        echo -e "\t- [cert_id] is the directory name of the certificate your wanna update, It's a string contains 6 letters like 'xgDShQ'. You can find it by \"$0 show\" to list all the certificates with their names. Omit it if you just want to update the default certificate."
        echo -e "\t- [domain] is your hostname."
        echo -e "\t- [dns] is your provider's name. Leave it to use the value in config."
        echo -e "\t- [date_time] is the timestamp of the backup you want to revert."
        echo -e "\t* [cert_id], [dns], [date_time] can be omitted."
        exit 1
esac
