# OpenSearch-Hadoop Issue #711 테스트 환경

[GitHub Issue #711](https://github.com/opensearch-project/opensearch-hadoop/issues/711) 재현을 위한 Docker Compose 기반 테스트 환경입니다.

**버그 요약:** `object` 타입에 `enabled: false`가 설정된 필드를 opensearch-hadoop 커넥터로 Spark에서 읽을 때, 실제로는 배열 of struct인 데이터가 **빈 struct 배열** `[{}, {}, ...]` 로 반환됨.

---

## 요구 사항

- Docker & Docker Compose
- (선택) 로컬에서만 OpenSearch 쓰고 Spark는 로컬에서 돌리려면 Java 11+, Spark 3.x, PySpark, opensearch-hadoop JAR

---

## 디렉터리 구조

```
opensearch-hadoop-issue-711/
├── docker-compose.yml      # OpenSearch + Spark 테스트 서비스
├── Dockerfile.spark-test   # Spark 3.4 (Bitnami ECR) + opensearch-hadoop 1.0.1 이미지 (spark-test / spark-test-fix 공용)
├── run_test.sh             # 컨테이너 내부 전체 테스트 진입점
├── scripts/
│   ├── setup_index.sh      # 인덱스 생성 + 테스트 도큐먼트 삽입
│   ├── verify_opensearch.sh # OpenSearch REST로 데이터 확인
│   └── spark_read_test.py  # PySpark로 읽기 테스트 (버그 재현)
├── test_output/            # (선택) 테스트 결과 저장
└── README.md
```

---

## 테스트 방법

### 방법 1: Docker Compose로 한 번에 실행 (권장)

OpenSearch 기동 → 인덱스 설정 → Spark로 읽기까지 한 번에 수행합니다.

```bash
cd /Users/yun-yeojeong/Project/test/opensearch-hadoop-issue-711

# 이미지 빌드 + 서비스 실행 (OpenSearch 기동 후 spark-test가 자동 실행)
docker compose up --build
```

- **OpenSearch**: `http://localhost:9200` 에서 접근 가능 (헬스 체크 후 spark-test 실행)
- **spark-test** (또는 **spark-test-fix**) 컨테이너가 자동으로:
  1. `setup_index.sh` 로 `test-index` 생성 및 테스트 도큐먼트 1건 삽입
  2. `spark_read_test.py` 로 opensearch-hadoop 커넥터를 사용해 읽기

**spark-test-fix**: spark-test와 **동일 이미지** 사용. fix 브랜치 JAR을 쓰려면 `docker-compose.yml`의 spark-test-fix 서비스에서 volume 주석을 해제하고 로컬 JAR 경로를 넣으면 됩니다 (예: `./download/opensearch-hadoop/spark/sql-30/build/libs/opensearch-spark-30_2.12-*.jar:/opt/connectors/opensearch-spark-30_2.12-1.0.1.jar`).

**버그가 재현되면** 터미널에 다음이 보입니다:

- 스키마에 `disabled_object: array<element: struct>` 이고 내부에 필드가 없음
- `df.show()` 에서 `disabled_object` 가 `[{}]` 또는 `[{}, {}]` 처럼 빈 struct만 나옴
- 스크립트 마지막에 `[버그 재현됨] disabled_object가 빈 struct 배열로 반환되었습니다.` 출력

---

### 방법 2: 단계별로 실행

#### 2-1. OpenSearch만 기동

```bash
cd /Users/yun-yeojeong/Project/test/opensearch-hadoop-issue-711
docker compose up -d opensearch
```

헬스 체크가 통과할 때까지 기다립니다 (보통 30초 내).

#### 2-2. 인덱스 생성 및 데이터 삽입

호스트에서 (OpenSearch가 localhost:9200 에 있을 때):

```bash
./scripts/setup_index.sh localhost
```

Docker 네트워크 안에서 실행할 때 (예: 다른 컨테이너에서):

```bash
./scripts/setup_index.sh opensearch
```

#### 2-3. OpenSearch에서 데이터 확인 (선택)

저장된 `_source` 가 기대한 대로인지 확인:

```bash
./scripts/verify_opensearch.sh localhost
```

`disabled_object` 에 `[{ "key1": "value1", "key2": 123 }, ...]` 가 보이면 정상입니다.

#### 2-4. Spark로 읽기 테스트

**A. Docker 안에서 (spark-test 컨테이너)**

```bash
docker compose run --rm spark-test
```

**B. 로컬에서 (Spark + opensearch-hadoop JAR 설치된 경우)**

이슈와 동일하게 [opensearch-spark-30_2.12-1.0.1.jar](https://repo1.maven.org/maven2/org/opensearch/client/opensearch-spark-30_2.12/1.0.1/) 등을 사용합니다.

```bash
export OPENSEARCH_HOST=localhost
export OPENSEARCH_PORT=9200

spark-submit \
  --master "local[*]" \
  --jars /path/to/opensearch-spark-30_2.12-1.0.1.jar \
  scripts/spark_read_test.py \
  localhost \
  9200
```

---

## 인덱스 매핑 (재현용)

이슈에서 사용한 것과 동일한 설정입니다.

- `normal_field`: `keyword`
- `disabled_object`: `object`, **`enabled: false`** → OpenSearch는 하위 필드를 인덱싱하지 않고 `_source` 에만 보관

```json
PUT /test-index
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
```

---

## 기대 동작 vs 버그 동작

| 구분 | OpenSearch REST (`_source`) | opensearch-hadoop으로 Spark 읽기 (현재 버그) |
|------|-----------------------------|----------------------------------------------|
| `disabled_object` | `[{ "key1": "value1", "key2": 123 }, ...]` | `[{}, {}]` (빈 struct 배열) |

스키마가 매핑에 하위 필드가 없어서 `ArrayType(StructType([]))` 로 추론되고, 이 때문에 실제 값이 채워지지 않는 것이 이슈의 원인입니다.

---

## 문제 해결 (Troubleshooting)

### OpenSearch 컨테이너가 exit 134로 종료될 때 (Docker Desktop Mac/Windows)

OpenSearch는 `vm.max_map_count`가 최소 262144여야 합니다. Docker Desktop은 호스트가 아닌 내부 Linux VM에서 컨테이너를 돌리기 때문에, **Docker가 쓰는 Linux VM 안에서** 아래 값을 설정해야 할 수 있습니다.

**방법 A – 터미널에서 Docker VM에 들어가서 설정**

```bash
# Docker Desktop이 사용하는 Linux VM에 접속 후
docker run --rm -it --privileged --pid=host alpine nsenter -t 1 -m -u -n -i -- sysctl -w vm.max_map_count=262144
```

**방법 B – 재시작 후에도 유지하려면**

Docker Desktop → Settings → Docker Engine에서 JSON에 다음을 추가할 수 없으면, 매번 `docker compose up` 전에 위 **방법 A**를 한 번 실행하세요.

**방법 C – 볼륨 초기화**

이전 실행에서 데이터가 깨졌을 수 있으므로, 볼륨을 지우고 다시 시도해 보세요.

```bash
docker compose down -v
docker compose up --build
```

---

## 정리

- **전체 자동 테스트**: `docker compose up --build`
- **단계별**: OpenSearch만 띄운 뒤 `setup_index.sh` → (선택) `verify_opensearch.sh` → `docker compose run --rm spark-test` 또는 로컬 `spark-submit`
- 버그 재현 시 터미널에 `[버그 재현됨]` 메시지와 빈 struct 배열이 출력됩니다.
