#!/bin/bash
set -e

# Ivy "basedir must be absolute" 오류 방지 (HOME 및 spark.jars.ivy 절대경로)
export HOME=/app
export SPARK_JARS_IVY=/app/.ivy2
mkdir -p "$SPARK_JARS_IVY"

# Kerberos 비활성화: Hadoop이 시작 시 읽는 설정 디렉터리 + JVM 옵션
export HADOOP_USER_NAME=spark
export HADOOP_CONF_DIR=/app/hadoop-conf
export SPARK_SUBMIT_OPTS="-Dhadoop.security.authentication=simple -Dhadoop.security.authorization=false"

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

if [ ! -f "${SPARK_OPENSEARCH_JAR}" ]; then
  echo "오류: 커넥터 JAR이 없습니다: ${SPARK_OPENSEARCH_JAR}"
  exit 1
fi

spark-submit \
  --master "local[*]" \
  --conf spark.jars.ivy="$SPARK_JARS_IVY" \
  --conf spark.hadoop.hadoop.security.authentication=simple \
  --conf spark.hadoop.hadoop.security.authorization=false \
  --jars "${SPARK_OPENSEARCH_JAR}" \
  /app/spark_read_test.py \
  "$OPENSEARCH_HOST" \
  "$OPENSEARCH_PORT" || { echo "spark-submit 실패 (exit $?)"; exit 1; }

echo ""
echo "테스트 완료."
