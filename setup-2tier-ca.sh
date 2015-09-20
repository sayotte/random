#!/bin/bash

cat - > new-root-batch.conf << EOF
[ req ]
distinguished_name = req_fields
prompt = no
x509_extensions = extensions

[ req_fields ]
C = US
ST = New York
L = Astoria
O = MyDomain.com
CN = root
emailAddress = me@mydomain.com

[ extensions ]
basicConstraints = CA:TRUE
keyUsage = keyCertSign, cRLSign
EOF

openssl genrsa -out root.key 2048
openssl req -new -key root.key -days 3650 -x509 -batch -config new-root-batch.conf -out root.pem

cat - > new-intermediate-batch.conf << EOF
[ req ]
distinguished_name = req_fields
prompt = no
x509_extensions = extensions

[ req_fields ]
C = US
ST = New York
L = Astoria
O = MyDomain.com
OU = TechOps DCA
CN = intermediate
emailAddress = me@mydomain.com

[ extensions ]
basicConstraints = CA:TRUE
keyUsage = keyCertSign, cRLSign

[ x509 ]
EOF
openssl genrsa -out intermediate.key 2048
openssl req -new -key intermediate.key -days 3650 -batch -config new-intermediate-batch.conf -out intermediate.req

cat - > root.conf << EOF
[ ca ]
default_ca = myca

[ crl_ext ]
# issuerAltName=issuer:copy  #this would copy the issuer name to altname
authorityKeyIdentifier=keyid:always

[ myca ]
new_certs_dir = root-certs/
unique_subject = no
certificate = root.pem 
database = root.db
private_key = root.key
serial = root-serial.txt
default_days = 3650
default_md = sha1
policy = myca_policy
x509_extensions = myca_extensions

[ myca_policy ]
commonName = supplied
emailAddress = optional
organizationName = supplied
organizationalUnitName = supplied

[ myca_extensions ]
basicConstraints = CA:TRUE
keyUsage = keyCertSign, cRLSign
subjectKeyIdentifier = hash
#authorityKeyIdentifier = keyid:always
crlDistributionPoints = URI:http://path.to.crl/myca.crl
EOF
mkdir root-certs
echo 0001 > root-serial.txt
touch root.db
openssl ca -batch -config root.conf -notext -in intermediate.req -out intermediate.pem

cat - > intermediate.conf << EOF
[ ca ]
default_ca = myca

[ crl_ext ]
# issuerAltName=issuer:copy  #this would copy the issuer name to altname
authorityKeyIdentifier=keyid:always

[ myca ]
new_certs_dir = intermediate-certs/
unique_subject = no
certificate = intermediate.pem
database = intermediate.db
private_key = intermediate.key 
serial = intermediate-serial.txt
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
mkdir intermediate-certs
touch intermediate.db
echo 0001 > intermediate-serial.txt

#keytool -genkey -alias agent -keyalg RSA -keystore agent.jks -keysize 2048 -storepass 123456 \
#	-dname "O=MyDomain.com, OU=IT, CN=somehost.mydomain.com/emailAddress=me@mydomain.com" \
#	-noprompt
#keytool -certreq -alias agent -keystore agent.jks -file pipedev.req -storepass 123456 -noprompt
openssl genrsa -out pipedev.key 2048
openssl req -new -key pipedev.key -days 3650 -batch -config intermediate.conf -out pipedev.req
openssl ca -batch -config intermediate.conf -notext -in pipedev.req -out pipedev.pem

cat pipedev.pem intermediate.pem root.pem > chain.pem
openssl pkcs12 -export -in chain.pem -inkey pipedev.key \
	-export -out pipedev.p12 \
	-name agent \
	-password pass:123456
keytool -importkeystore -deststorepass 123456 -destkeystore agent.jks \
	-srckeystore pipedev.p12 -srcstoretype PKCS12 -srcstorepass 123456 \
	-alias agent
#keytool -importcert -alias root -file root.pem -keystore agent.jks -storepass 123456
#keytool -importcert -alias intermediate -file intermediate.pem -keystore agent.jks -storepass 123456
#keytool -importcert -alias agent -file pipedev.pem -keystore agent.jks -storepass 123456

