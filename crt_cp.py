#!/bin/python2

# this script copies cert recorded in INFO file from src to des.

import json
import sys
import shutil
import os

CERT_FILES = [
    'cert.pem',
    'privkey.pem',
    'fullchain.pem'
]

SRC_DIR_NAME = sys.argv[1]

CERT_BASE_PATH = '/usr/syno/etc/certificate'

ARCHIEV_PATH = CERT_BASE_PATH + '/_archive'
INFO_FILE_PATH = ARCHIEV_PATH + '/INFO'

services = []
try:
    info = json.load(open(INFO_FILE_PATH))
    services = info[SRC_DIR_NAME]['services']
except:
    print '[ERR] load INFO file- %s fail' %(INFO_FILE_PATH,) 
    sys.exit(1)

CP_FROM_DIR = ARCHIEV_PATH + '/' + SRC_DIR_NAME
for service in services:
    CP_TO_DIR = '%s/%s/%s' %(CERT_BASE_PATH, service['subscriber'], service['service'])
    if not os.path.exists(CP_TO_DIR):
        os.makedirs(CP_TO_DIR)
    for f in CERT_FILES:
        src = CP_FROM_DIR + '/' + f 
        des = CP_TO_DIR + '/' + f
        print src, des
        try:
            shutil.copy2(src, des)
        except:
            print '[WRN] copy from %s to %s fail' %(src, des)
