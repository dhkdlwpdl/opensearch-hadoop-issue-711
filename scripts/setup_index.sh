#!/bin/bash
# OpenSearch 인덱스 생성 및 테스트 데이터 삽입 (이슈 #711 재현용)
# 사용법: ./setup_index.sh [OPENSEARCH_HOST]
# 기본 호스트: localhost (로컬) 또는 opensearch (Docker 내부)

set -e
OPENSEARCH_HOST="${1:-localhost}"
OPENSEARCH_URL="http://${OPENSEARCH_HOST}:9200"

echo "=== OpenSearch 연결: $OPENSEARCH_URL ==="

# 헬스 체크
until curl -s "${OPENSEARCH_URL}/_cluster/health" | grep -q '"status"'; do
  echo "OpenSearch 대기 중..."
  sleep 2
done
echo "OpenSearch 준비됨."

# 기존 인덱스 삭제 (재실행 시)
curl -s -X DELETE "${OPENSEARCH_URL}/test-index" | true

# 1. 인덱스 생성 (enabled: false 오브젝트 필드 포함)
echo ""
echo "=== 인덱스 생성 (disabled_object: enabled false) ==="
curl -s -X PUT "${OPENSEARCH_URL}/test-index" -H 'Content-Type: application/json' -d'
{
  "mappings": {
    "properties": {
      "normal_field": { "type": "keyword" },
      "disabled_object": {
        "type": "object",
        "enabled": false
      }
    }
  }
}
'
echo ""

# 2. 테스트 도큐먼트 인덱싱
echo "=== 테스트 도큐먼트 인덱싱 ==="
curl -s -X POST "${OPENSEARCH_URL}/test-index/_doc" -H 'Content-Type: application/json' -d'
{
  "normal_field": "hello",
  "disabled_object": [
    { "key1": "value1", "key2": 123 },
    { "key1": "value2", "key2": 456 }
  ]
}
'
echo ""

# 3. refresh 후 검색으로 저장 확인
curl -s -X POST "${OPENSEARCH_URL}/test-index/_refresh" > /dev/null
echo "=== OpenSearch에서 직접 조회 (기대값: disabled_object 배열이 그대로 보여야 함) ==="
curl -s -X GET "${OPENSEARCH_URL}/test-index/_search" -H 'Content-Type: application/json' -d'{"size": 1}' | python3 -m json.tool 2>/dev/null || cat

echo ""
echo "설정 완료. 이제 Spark(opensearch-hadoop)로 읽어보면 disabled_object가 빈 struct 배열로 나오는 버그를 확인할 수 있습니다."
