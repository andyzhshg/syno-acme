source ./config

DATE_TIME=`date +%Y%m%d-%H%M%S`
echo '-------------------------------'
echo 'cert update begin'
echo ${DATE_TIME}

echo 'finding default cert path...'
CERT_BASE_PATH="/usr/syno/etc/certificate/_archive"
CERT_PATH_NAME=`cat ${CERT_BASE_PATH}/DEFAULT`
CERT_PATH=${CERT_BASE_PATH}/${CERT_PATH_NAME}
if [ ! -d  ${CERT_PATH} ]; then
  echo '[ERR] default cert path not found.'
  exit 1
fi

echo 'backup default cert...'
BACKUP_BASE=${CERT_BASE_PATH}/backup
mkdir -p ${BACKUP_BASE}
cp -r ${CERT_PATH} ${BACKUP_BASE}/${CERT_PATH_NAME}-${DATE_TIME}

BASE_ROOT=$(cd "$(dirname "$0")";pwd)

cd ${BASE_ROOT}
echo 'downloading acme.sh tool...'
ACME_SH_ADDRESS=`curl -L https://raw.githubusercontent.com/andyzhshg/syno-acme/master/acme.sh.address`
SRC_TAR_NAME=acme.sh.tar.gz
curl -L -o ${SRC_TAR_NAME} ${ACME_SH_ADDRESS}
SRC_NAME=`tar -tzf ${SRC_TAR_NAME} | head -1 | cut -f1 -d"/"`
tar zxvf acme.sh.tar.gz

echo 'installing cme.sh tool...'
cd ${SRC_NAME}
BIN_PATH=${BASE_ROOT}/acme.sh
./acme.sh --install --nocron --home ${BIN_PATH}

cd ${BASE_ROOT}

echo 'updating default cert by acme.sh tool'
source ${BIN_PATH}/acme.sh.env

${BIN_PATH}/acme.sh --issue --dns ${DNS} -d *.${DOMAIN}
${BIN_PATH}/acme.sh --installcert -d *.${DOMAIN} \
    --certpath ${CERT_PATH}/cert.pem \
    --key-file ${CERT_PATH}/privkey.pem \
	--fullchain-file ${CERT_PATH}/fullchain.pem

echo 'removing temp data...'
rm ${SRC_TAR_NAME}
rm -rf ${SRC_NAME}
rm -rf ${BIN_PATH}

echo 'reloading new cert...'
/usr/syno/etc/rc.sysv/nginx.sh reload

echo 'cert update done!'
echo '-------------------------------------------------'

