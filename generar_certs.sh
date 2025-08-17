#!/usr/bin/env bash

set -e
echo "Generando CA y certificados para es01, es02, es03 y kibana en ./certs"

# 1. Crear CA
mkdir -p certs/ca
openssl genrsa -out certs/ca/ca.key 4096
openssl req -x509 -new -nodes -key certs/ca/ca.key -sha256 -days 3650 \
  -subj "/C=ES/O=Lab/OU=Elastic/CN=elastic-ca" \
  -out certs/ca/ca.crt

# 2. Generar certificados para cada nodo
for node in es01 es02 es03 kibana; do
  mkdir -p certs/$node
  openssl genrsa -out certs/$node/$node.key 2048
  openssl req -new -key certs/$node/$node.key \
    -subj "/C=ES/O=Lab/OU=Elastic/CN=$node" \
    -out certs/$node/$node.csr

  cat > certs/$node/$node.ext <<EOF
subjectAltName=DNS:$node,DNS:localhost,IP:127.0.0.1
extendedKeyUsage=serverAuth,clientAuth
EOF

  openssl x509 -req -in certs/$node/$node.csr \
    -CA certs/ca/ca.crt -CAkey certs/ca/ca.key -CAcreateserial \
    -out certs/$node/$node.crt -days 1825 -sha256 -extfile certs/$node/$node.ext

  rm certs/$node/$node.csr certs/$node/$node.ext
done

# 3. Ajustar permisos
find certs -type f -name "*.key" -exec chmod 640 {} \;
find certs -type f -name "*.crt" -exec chmod 644 {} \;

echo "Listo. Revisa ./certs queda montar estas rutas en Docker."

