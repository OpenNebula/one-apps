CA certificate
==============

1. Key
```
openssl genrsa -des3 -out one_CA.key 2048
```

2. Certificate
```
openssl req -x509 -new -nodes -key one_CA.key -sha256 -days 3650 -out one_CA.pem
```

CN data:
```
-----
Country Name (2 letter code) [XX]:ES
State or Province Name (full name) []:MAD
Locality Name (eg, city) [Default City]:MAD
Organization Name (eg, company) [Default Company Ltd]:ONE
Organizational Unit Name (eg, section) []:DEV
Common Name (eg, your name or your server's hostname) []:OpenNebula CA
Email Address []:ca@opennebula.org
```

3. Hash
```
openssl x509 -hash -noout -in  one_CA.pem
```

User Certificate
================

1. Generate Request
```
openssl req --newkey rsa:2048 -nodes -days 3650 -keyout x509_user_key.pem -out x509_user_req.pem
```

CN data:
```
-----
Country Name (2 letter code) [XX]:ES
State or Province Name (full name) []:MAD
Locality Name (eg, city) [Default City]:MAD
Organization Name (eg, company) [Default Company Ltd]:ONE
Organizational Unit Name (eg, section) []:DEV
Common Name (eg, your name or your server's hostname) []:x509_user
Email Address []:x509_user@opennebula.org
```

2. Sign with CA cert
```
openssl x509 -req -days 3650 -set_serial 01 -in ./x509_user_req.pem -out ./x509_user_cert.pem -CA one_CA.pem -CAkey one_CA.key
```
