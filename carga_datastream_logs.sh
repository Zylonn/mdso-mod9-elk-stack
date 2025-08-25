#!/usr/bin/env bash

# =========================
# Configuración
# =========================
HOST="https://localhost:9200"
DATA_STREAM="master-app"            # Nombre del data stream 
USER="elastic"
PASSWORD="devsecops"
CA_CERT="./certs/ca/ca.crt"       # Ruta certs

# Parámetros de carga
NUM_DOCS=10000
INTERVALO=1                       # segundos entre documentos

# Pon PAYLOAD_BYTES>0 --> Añade un campo 'blob' tamaño en bytes
PAYLOAD_BYTES=100000                   # 50000 -> ~50 KB por doc

# =========================
# Pre-chequeos
# =========================

# Compruebo que el CA existe
if [ ! -f "$CA_CERT" ]; then
  echo "No encuentro el CA en: $CA_CERT"
  echo "Ajusta la ruta de CA_CERT."
  exit 1
fi

# Compruebo que el data stream existe
echo "Comprobando data stream '$DATA_STREAM' en $HOST..."
HTTP_CODE=$(curl -sS --cacert "$CA_CERT" -u "$USER:$PASSWORD" -o /dev/null -w "%{http_code}" \
  -X GET "$HOST/_data_stream/$DATA_STREAM")

if [ "$HTTP_CODE" != "200" ]; then
  echo "El data stream '$DATA_STREAM' no existe o no es accesible (HTTP $HTTP_CODE)."
  echo "Créalo antes, por ejemplo:"
  echo "  PUT _index_template/tpl-logs ...  (con index.lifecycle.name, mappings con @timestamp, etc.)"
  echo "  PUT _data_stream/$DATA_STREAM"
  exit 1
fi

echo "Enviando $NUM_DOCS documentos al data stream '$DATA_STREAM' en $HOST"
echo

# =========================
# Función para generar carga opcional
# =========================
make_payload() {
  if [ "$PAYLOAD_BYTES" -le 0 ]; then
    echo ""
    return
  fi
  # Genero una cadena pseudoaleatoria de PAYLOAD_BYTES
  python3 - "$PAYLOAD_BYTES" << 'PY'
import sys, random, string
n = int(sys.argv[1])
s = ''.join(random.choices(string.ascii_letters + string.digits, k=n))
print(s)
PY
}

# =========================
# Envío de documentos
# =========================
for i in $(seq 1 "$NUM_DOCS"); do
  FECHA=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  BLOB=$(make_payload)

  # Importante: para data streams indexo en /<data-stream>/_doc
  if [ -z "$BLOB" ]; then
    curl -sS --cacert "$CA_CERT" -u "$USER:$PASSWORD" \
      -X POST "$HOST/$DATA_STREAM/_doc" \
      -H 'Content-Type: application/json' \
      -d "{
        \"@timestamp\": \"$FECHA\",
        \"message\": \"Log $i generado automáticamente\",
        \"nivel\": \"info\",
        \"host\": \"vm-ubuntu\",
        \"service\": \"simulador-logs\"
      }" > /dev/null
  else
    # Con campo grande para forzar tamaño
    BLOB_ESCAPED=$(printf '%s' "$BLOB" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])')
    curl -sS --cacert "$CA_CERT" -u "$USER:$PASSWORD" \
      -X POST "$HOST/$DATA_STREAM/_doc" \
      -H 'Content-Type: application/json' \
      -d "{
        \"@timestamp\": \"$FECHA\",
        \"message\": \"Log $i generado automáticamente\",
        \"nivel\": \"info\",
        \"host\": \"vm-ubuntu\",
        \"service\": \"simulador-logs\",
        \"blob\": \"$BLOB_ESCAPED\"
      }" > /dev/null
  fi

  echo "[$i/$NUM_DOCS] Documento enviado con timestamp $FECHA"
  sleep "$INTERVALO"
done

echo
echo "Carga completada. Verifica en Kibana -> Index Management -> Data Streams e ILM Explain."
