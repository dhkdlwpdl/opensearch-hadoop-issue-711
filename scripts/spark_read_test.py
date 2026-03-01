#!/usr/bin/env python3
"""
이슈 #711 재현: opensearch-hadoop 커넥터로 object + enabled:false 필드 읽기 시
빈 struct 배열이 반환되는 버그 테스트

실행 예 (spark-submit):
  spark-submit --jars /path/to/opensearch-spark-30_2.12-1.0.1.jar \
    spark_read_test.py <opensearch_host> [opensearch_port]
"""
import os
import sys

from pyspark.sql import SparkSession

def main():
    opensearch_host = os.environ.get("OPENSEARCH_HOST", "localhost")
    opensearch_port = os.environ.get("OPENSEARCH_PORT", "9200")
    if len(sys.argv) >= 2:
        opensearch_host = sys.argv[1]
    if len(sys.argv) >= 3:
        opensearch_port = sys.argv[2]

    nodes = f"{opensearch_host}:{opensearch_port}"

    spark = (
        SparkSession.builder
        .appName("opensearch-hadoop-issue-711-test")
        .config("spark.sql.adaptive.enabled", "false")
        .getOrCreate()
    )

    print("=" * 60)
    print("OpenSearch 노드:", nodes)
    print("=" * 60)

    df = (
        spark.read
        .format("opensearch")
        .option("opensearch.nodes", nodes)
        .option("opensearch.resource", "test-index")
        .option("opensearch.read.field.as.array.include", "disabled_object")
        .load()
    )

    print("\n--- 스키마 (inferred) ---")
    df.printSchema()

    print("\n--- df.show() 결과 ---")
    df.show(truncate=False)

    print("\n--- disabled_object 컬럼만 출력 ---")
    df.select("disabled_object").show(truncate=False)

    # 버그 확인: disabled_object가 [{}, {}] 형태면 버그 재현된 것
    row = df.first()
    if row is not None and "disabled_object" in row.asDict():
        val = row["disabled_object"]
        if val is not None and len(val) > 0:
            first_elem = val[0] if hasattr(val, "__getitem__") else None
            if first_elem is not None and isinstance(first_elem, dict) and len(first_elem) == 0:
                print("\n[버그 재현됨] disabled_object가 빈 struct 배열로 반환되었습니다.")
                print("  기대값: [{\"key1\": \"value1\", \"key2\": 123}, ...]")
            else:
                print("\n[정상] disabled_object에 하위 필드가 포함되어 있습니다.")

    spark.stop()

if __name__ == "__main__":
    main()
