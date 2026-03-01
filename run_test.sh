#!/bin/bash
set -e

OPENSEARCH_HOST="${OPENSEARCH_HOST:-opensearch}"
OPENSEARCH_PORT="${OPENSEARCH_PORT:-9200}"

echo "=============================================="
echo "1. OpenSearch 인덱스 생성 및 데이터 삽입"
echo "=============================================="
/app/scripts/setup_index.sh "$OPENSEARCH_HOST"

echo ""
echo "=============================================="
echo "2. Spark(opensearch-hadoop)로 읽기 테스트"
echo "=============================================="
export OPENSEARCH_HOST
export OPENSEARCH_PORT

spark-submit \
  --master "local[*]" \
  --jars "${SPARK_OPENSEARCH_JAR}" \
  /app/spark_read_test.py \
  "$OPENSEARCH_HOST" \
  "$OPENSEARCH_PORT"

echo ""
echo "테스트 완료."
