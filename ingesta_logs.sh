#!/bin/bash

# Configuración
HOST="https://localhost:9200"
INDEX_ALIAS="master-arq-logs"
USER="elastic"
PASSWORD="devsecops"
CA_CERT="./certs/ca/ca.crt"  

# Número de documentos a insertar
NUM_DOCS=10000
INTERVALO=1  # en segundos

echo "Enviando $NUM_DOCS documentos al índice '$INDEX_ALIAS' en $HOST"
echo

for i in $(seq 1 $NUM_DOCS); do
  FECHA=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  curl -s -k --cacert "$CA_CERT" -u "$USER:$PASSWORD" -X POST "$HOST/$INDEX_ALIAS/_doc" -H 'Content-Type: application/json' -d "
  {
    \"@timestamp\": \"$FECHA\",
    \"message\": \"Log $i generado automáticamente\",
    \"nivel\": \"info\",
    \"host\": \"vm-ubuntu\",
    \"service\": \"simulador-logs\"
  }" > /dev/null

  echo "[$i/$NUM_DOCS] Documento enviado con timestamp $FECHA"
  sleep $INTERVALO
done

echo
echo "Carga completada. Puedes verificar en Kibana -> Index Management -> ILM."
