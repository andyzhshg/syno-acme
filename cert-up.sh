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
CRT_PATH_NAME=`cat ${CRT_BASE_PATH}/_archive/DEFAULT`
CRT_PATH=${CRT_BASE_PATH}/_archive/${CRT_PATH_NAME}
FIND_MAJORVERSION_FILE="/etc/VERSION"
FIND_MAJORVERSION_STR="majorversion=\"7\""

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

versionLt () { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }
installAcme () {
  ALLOW_INSTALL=false
  ACME_SH_FILE=${ACME_BIN_PATH}/acme.sh
  ACME_SH_NEW_VERSION=$(wget -qO- -t1 -T2 "https://api.github.com/repos/acmesh-official/acme.sh/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
  ACME_SH_ADDRESS=https://mirror.ghproxy.com/https://github.com/acmesh-official/acme.sh/archive/${ACME_SH_NEW_VERSION}.tar.gz
  if [ -z "${ACME_SH_NEW_VERSION}" ]; then
    echo 'unable to get new version number'
    return 0
  fi
  if [ ! -f "${ACME_SH_FILE}" ]; then
    ALLOW_INSTALL=true
    echo 'acme not installed, start install'
  else
    ACME_SH_VERSION=$(cat ${ACME_SH_FILE} | grep "VER=*" | head -n 1 | awk -F "=" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
    if versionLt ${ACME_SH_VERSION} ${ACME_SH_NEW_VERSION}; then
      ALLOW_INSTALL=true
      echo 'acme has a new version, start updating'
    else
      echo 'skip acme installation'
    fi
  fi
  if [ ${ALLOW_INSTALL} == true ]; then
    echo 'in progress...'
    mkdir -p ${TEMP_PATH}
    cd ${TEMP_PATH}
    echo 'begin downloading acme.sh tool...'
    # ACME_SH_ADDRESS=`curl -L https://cdn.jsdelivr.net/gh/andyzhshg/syno-acme@master/acme.sh.address`
    SRC_TAR_NAME=acme.sh.tar.gz
    curl -L -o ${SRC_TAR_NAME} ${ACME_SH_ADDRESS}
    SRC_NAME=`tar -tzf ${SRC_TAR_NAME} | head -1 | cut -f1 -d"/"`
    tar zxvf ${SRC_TAR_NAME}
    echo 'begin installing acme.sh tool...'
    cd ${SRC_NAME}
    ./acme.sh --install --nocron --home ${ACME_BIN_PATH}
    echo 'done installAcme'
    rm -rf ${TEMP_PATH}
  fi
  return 0
}

generateCrt () {
  echo 'begin generateCrt'
  cd ${BASE_ROOT}
  source ./config
  # add register zerossl account
  if [ ${CERT_SERVER} == 'zerossl' ]; then
    echo 'register zerossl account'
    ${ACME_BIN_PATH}/acme.sh  --register-account  -m ${ACCOUNT_EMAIL} --server zerossl
  fi
  echo 'begin updating default cert by acme.sh tool'
  source ${ACME_BIN_PATH}/acme.sh.env
  # ${ACME_BIN_PATH}/acme.sh --force --log --issue --dns ${DNS} --dnssleep ${DNS_SLEEP} -d "${DOMAIN}" -d "*.${DOMAIN}"
  ${ACME_BIN_PATH}/acme.sh --force --log --issue --server ${CERT_SERVER} --dns ${DNS} --dnssleep ${DNS_SLEEP} -d "${DOMAIN}" -d "*.${DOMAIN}"
  ${ACME_BIN_PATH}/acme.sh --force --installcert -d ${DOMAIN} -d *.${DOMAIN} \
    --certpath ${CRT_PATH}/cert.pem \
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
  if [ `grep -c "$FIND_MAJORVERSION_STR" $FIND_MAJORVERSION_FILE` -ne '0' ];then
    echo "MajorVersion = 7, use system default python2"
    python2 ${BASE_ROOT}/crt_cp.py ${CRT_PATH_NAME}
  else
    echo "MajorVersion < 7"
    /bin/python2 ${BASE_ROOT}/crt_cp.py ${CRT_PATH_NAME}
  fi
  echo 'done updateService'
}

reloadWebService () {
  echo 'begin reloadWebService'
  echo 'reloading new cert...'
  if [ `grep -c "$FIND_MAJORVERSION_STR" $FIND_MAJORVERSION_FILE` -ne '0' ];then
    echo "MajorVersion = 7"
    synow3tool --gen-all && systemctl reload nginx
  else
    echo "MajorVersion < 7"
    /usr/syno/etc/rc.sysv/nginx.sh reload
  fi
  if [ `grep -c "$FIND_MAJORVERSION_STR" $FIND_MAJORVERSION_FILE` -ne '0' ];then
    echo "MajorVersion = 7, no need to reload apache"
  else
	echo 'relading Apache on DSM 6.x'
	stop pkg-apache22
	start pkg-apache22
	reload pkg-apache22
  fi  
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
    updateCrt
    ;;

  revert)
    echo "begin revert"
      revertCrt $2
      ;;

    *)
        echo "Usage: $0 {update|revert}"
        exit 1
esac
