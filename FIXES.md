# 이슈별 수정 내역 (opensearch-hadoop #711 테스트 환경)

Docker 기반 테스트 환경 구성 시 해결한 이슈들을 정리합니다.


| 이슈                                  | 원인                                 | 조치                                                                                             |
| ----------------------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------------- |
| Bitnami Spark 이미지 없음                | Docker Hub `bitnami/spark` 태그 미제공  | ECR 공개 이미지 `public.ecr.aws/bitnami/spark:3.4.1` 사용                                             |
| OpenSearch exit 134 (Apple Silicon) | memory_lock, Java 21 SIGILL        | `memory_lock=false`, OpenSearch 2.11.1(Java 17), `platform: linux/arm64`                       |
| sysctl vm.max_map_count 오류          | 컨테이너에서 해당 sysctl 미지원               | compose에서 sysctl 제거, README에 호스트 설정 방법 안내                                                      |
| spark-test 플랫폼 경고                   | Bitnami Spark amd64 전용             | `platform: linux/amd64` 명시                                                                     |
| Ivy "basedir must be absolute"      | HOME 미설정 → `?/.ivy2/local`         | `HOME=/app`, `spark.jars.ivy=/app/.ivy2`, run_test.sh에서 설정                                     |
| JAR 읽기 실패                           | root 소유로 USER 1001 미접근             | `chown -R 1001:root /opt/connectors /app`                                                      |
| KerberosAuthException               | Hadoop Kerberos 시도, UID 1001 이름 없음 | `core-site.xml`(simple), `HADOOP_CONF_DIR`, `SPARK_SUBMIT_OPTS`, `/etc/passwd`에 spark(1001) 등록 |
| Provider DefaultSource15 not found  | DataSourceRegister가 드라이버 클래스패스에서 로드되지 않음 | `--driver-class-path`에 커넥터 JAR 추가, Spark `jars/`에 복사; 빌드 시 JAR 내 DefaultSource15 포함 여부 검증 |
| OpenSearchHadoopIllegalStateException (spark-test-fix) | 포크 빌드 JAR이 embedded를 .class가 아닌 소스만 포함 → 공식 .class만 보강해도 의존 클래스 부족 | spark-test-fix는 Custom Dockerfile로 전환. `connectors/`에 JAR 넣고 `Dockerfile.spark-test.custom`로 빌드 |
| JAR 취득 방식 분기 | Official(다운로드) vs Custom(로컬 JAR) 둘 다 지원 | `Dockerfile.spark-test` = Maven 다운로드, `Dockerfile.spark-test.custom` = `connectors/` 디렉터리 JAR를 ADD. 나머지 레이어 공통 |


