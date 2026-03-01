#!/bin/bash
# OpenSearch에 저장된 데이터를 REST API로 직접 조회 (정상 동작 확인)
OPENSEARCH_HOST="${1:-localhost}"
OPENSEARCH_URL="http://${OPENSEARCH_HOST}:9200"

echo "=== GET test-index/_search (원본 _source 확인) ==="
curl -s -X GET "${OPENSEARCH_URL}/test-index/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "size": 5,
  "_source": true
}
'
