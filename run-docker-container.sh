#!/bin/bash

################################################################################
# Docker 컨테이너 실행 스크립트 (Frontend)
# 용도: Docker 컨테이너 실행 (환경변수는 Dockerfile ENV 사용)
# 사용: ./scripts/run-docker-container.sh <이미지명>
# 예시: ./scripts/run-docker-container.sh registry.ktb-waf.cloud/ktb-fe:2025-1120-2
################################################################################

set -e  # 에러 발생 시 스크립트 중지

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 인자 확인
if [ $# -eq 0 ]; then
    echo -e "${RED}에러: Docker 이미지명을 지정해주세요.${NC}"
    echo ""
    echo "사용법:"
    echo "  ./scripts/run-docker-container.sh <이미지명>"
    echo ""
    echo "예시:"
    echo "  ./scripts/run-docker-container.sh registry.ktb-waf.cloud/ktb-fe:2025-1120-2"
    echo "  ./scripts/run-docker-container.sh registry.ktb-waf.cloud/ktb-fe:latest"
    echo ""
    exit 1
fi

# 설정
CONTAINER_NAME="community-frontend"
IMAGE_NAME="$1"  # 첫 번째 인자를 이미지명으로 사용
CONTAINER_PORT=3000
HOST_PORT=3000
MEMORY_LIMIT="512m"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Docker 컨테이너 실행 시작${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

################################################################################
# 1. 사전 검증
################################################################################

echo -e "${YELLOW}[1/5] 사전 검증${NC}"

# Docker 설치 확인
if ! command -v docker &> /dev/null; then
    echo -e "${RED}에러: Docker가 설치되어 있지 않습니다.${NC}"
    exit 1
fi
echo "  ✓ Docker 설치됨"

# Docker 이미지 존재 확인 (로컬 또는 원격)
echo "  이미지 확인 중: $IMAGE_NAME"
if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^$IMAGE_NAME$"; then
    echo "  로컬에 이미지가 없습니다. 원격에서 pull을 시도합니다..."
    if ! docker pull "$IMAGE_NAME"; then
        echo -e "${RED}에러: Docker 이미지를 찾을 수 없습니다: $IMAGE_NAME${NC}"
        echo ""
        echo "다음 명령어로 이미지를 빌드하세요:"
        echo "  docker buildx build --platform linux/amd64 -t $IMAGE_NAME --load ."
        echo ""
        echo "또는 이미지를 푸시하세요:"
        echo "  docker push $IMAGE_NAME"
        exit 1
    fi
fi
echo "  ✓ Docker 이미지 존재: $IMAGE_NAME"
echo ""

################################################################################
# 2. 기존 컨테이너 확인 및 중지
################################################################################

echo -e "${YELLOW}[2/5] 기존 컨테이너 확인${NC}"

if docker ps -a | grep -q "$CONTAINER_NAME"; then
    echo "  기존 컨테이너 발견: $CONTAINER_NAME"

    if docker ps | grep -q "$CONTAINER_NAME"; then
        echo "  컨테이너 중지 중..."
        docker stop "$CONTAINER_NAME"
    fi

    echo "  컨테이너 삭제 중..."
    docker rm "$CONTAINER_NAME"
    echo -e "  ${GREEN}✓ 기존 컨테이너 정리 완료${NC}"
else
    echo "  기존 컨테이너 없음"
fi
echo ""

################################################################################
# 3. Docker 컨테이너 실행
################################################################################

echo -e "${YELLOW}[3/5] Docker 컨테이너 실행${NC}"
echo "  이미지: $IMAGE_NAME"
echo "  컨테이너: $CONTAINER_NAME"
echo "  포트: $HOST_PORT:$CONTAINER_PORT"
echo "  메모리 제한: $MEMORY_LIMIT"
echo "  환경 변수: Dockerfile ENV 사용 (BACKEND_URL='', LAMBDA_API_URL='/images')"
echo ""

docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p "$HOST_PORT:$CONTAINER_PORT" \
    --memory="$MEMORY_LIMIT" \
    --memory-swap="$MEMORY_LIMIT" \
    "$IMAGE_NAME"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 컨테이너 시작 성공${NC}"
else
    echo -e "${RED}✗ 컨테이너 시작 실패${NC}"
    echo ""
    echo "로그 확인:"
    echo "  docker logs $CONTAINER_NAME"
    exit 1
fi
echo ""

################################################################################
# 4. 헬스 체크
################################################################################

echo -e "${YELLOW}[4/5] 헬스 체크 (최대 30초 대기)${NC}"

MAX_ATTEMPTS=30
ATTEMPT=0
HEALTH_URL="http://localhost:$HOST_PORT"

echo -n "  프론트엔드 서버 시작 대기 중"

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s -f "$HEALTH_URL" > /dev/null 2>&1; then
        echo ""
        echo -e "${GREEN}✓ 헬스 체크 성공 (${ATTEMPT}초)${NC}"
        break
    fi

    echo -n "."
    sleep 1
    ATTEMPT=$((ATTEMPT + 1))
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo ""
    echo -e "${RED}✗ 헬스 체크 실패 (30초 타임아웃)${NC}"
    echo ""
    echo "컨테이너 로그:"
    docker logs --tail 30 "$CONTAINER_NAME"
    echo ""
    echo "컨테이너가 시작되지 않았습니다."
    echo "위 로그를 확인하고 문제를 해결하세요."
    exit 1
fi
echo ""

################################################################################
# 5. 배포 완료
################################################################################

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}배포 완료! ✅${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 컨테이너 정보 출력
echo "컨테이너 상태:"
docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "유용한 명령어:"
echo "  - 로그 확인: docker logs -f $CONTAINER_NAME"
echo "  - 컨테이너 중지: docker stop $CONTAINER_NAME"
echo "  - 컨테이너 재시작: docker restart $CONTAINER_NAME"
echo "  - config.js 확인: docker exec $CONTAINER_NAME cat /app/origin_source/static/config.js"
echo "  - 환경 변수 확인: docker exec $CONTAINER_NAME printenv | grep -E 'BACKEND_URL|LAMBDA_API_URL'"
echo ""

echo "접속 URL:"
echo "  - 로컬 테스트: http://localhost:$HOST_PORT"
echo "  - 프로덕션: https://community.ktb-waf.cloud (Nginx 라우팅)"
echo ""

echo -e "${BLUE}축하합니다! 프론트엔드 서버가 성공적으로 시작되었습니다. 🚀${NC}"
echo ""
