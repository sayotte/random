#!/bin/bash

cat - > new-root-batch.conf << EOF
[ req ]
distinguished_name = req_fields
prompt = no
x509_extensions = extensions

[ req_fields ]
C = US
ST = Georgia
L = Atlanta
O = Soulflops.net
CN = root
emailAddress = stephen.ayotte@gmail.com

[ extensions ]
basicConstraints = CA:TRUE
keyUsage = keyCertSign, cRLSign
EOF

openssl genrsa -out root.key 2048
openssl req -new -key root.key -days 3650 -x509 -batch -config new-root-batch.conf -out root.pem

cat - > root.conf << EOF
[ ca ]
default_ca = myca

[ crl_ext ]
# issuerAltName=issuer:copy  #this would copy the issuer name to altname
authorityKeyIdentifier=keyid:always

[ myca ]
new_certs_dir = certs/
unique_subject = no
certificate = root.pem
database = root.db
private_key = root.key 
serial = serial.txt
default_days = 365
default_md = sha1
policy = myca_policy
x509_extensions = myca_extensions

[ myca_policy ]
commonName = supplied
emailAddress = optional
organizationName = supplied
organizationalUnitName = supplied

[ myca_extensions ]
basicConstraints = CA:false
subjectKeyIdentifier = hash
#authorityKeyIdentifier = keyid:always
keyUsage = digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
crlDistributionPoints = URI:http://path.to.crl/myca.crl
[ req ]
default_bits = 2048
distinguished_name = req_fields
prompt = yes

[ req_fields ]
O = "Organization"
O_default = "MyDomain.com"
OU = "Organizational Unit"
OU_default = "IT"
CN = "Fully-qualified Hostname"
CN_default = "somehost.mydomain.com"
emailAddress = "Email address"
emailAddress_default = "me@mydomain.com"
EOF
mkdir certs
touch root.db
echo 0001 > serial.txt

