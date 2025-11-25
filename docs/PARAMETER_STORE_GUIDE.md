# AWS Parameter Store 등록 가이드 (Frontend)

**프로젝트**: KTB 커뮤니티 플랫폼 - 프론트엔드
**업데이트**: 2025-01-20
**Nginx 라우팅**: Path-based (https://community.ktb-waf.cloud/*)

---

## 📋 목차

1. [개요](#개요)
2. [Parameter 목록](#parameter-목록)
3. [등록 방법](#등록-방법)
4. [IAM 권한 설정](#iam-권한-설정)
5. [검증 방법](#검증-방법)
6. [트러블슈팅](#트러블슈팅)

---

## 개요

**Parameter Store 사용 목적:**
- 환경별 설정 분리 (로컬 개발 / EC2 배포)
- 민감 정보 제외 (도메인 URL은 민감하지 않지만 중앙 관리)
- 재배포 없이 설정 변경 가능

**환경 변수 주입 플로우:**
```
Parameter Store → run-docker-container.sh → docker run -e → server.js → config.js → window.APP_CONFIG
```

---

## Parameter 목록

### 1. BACKEND_URL (백엔드 API Base URL)

**Parameter Name:** `/ktb-community/frontend/backend-url`

**설정 값:**
- **EC2 프로덕션**: `""` (빈 문자열, 상대 경로 사용)
- **로컬 개발**: `"http://localhost:8080"` (직접 호출)

**이유:**
- Nginx가 `https://community.ktb-waf.cloud/posts` → `http://backend:8080/posts`로 라우팅
- Same-Origin 요청 → CORS 문제 없음
- 빈 문자열 사용 시 `/posts` → 상대 경로로 변환

**등록 명령어:**
```bash
# EC2 프로덕션 (권장)
aws ssm put-parameter \
  --name "/ktb-community/frontend/backend-url" \
  --value "" \
  --type String \
  --region ap-northeast-2 \
  --overwrite

# 또는 절대 경로 (옵션)
aws ssm put-parameter \
  --name "/ktb-community/frontend/backend-url" \
  --value "https://community.ktb-waf.cloud" \
  --type String \
  --region ap-northeast-2 \
  --overwrite
```

---

### 2. LAMBDA_API_URL (이미지 업로드 API)

**Parameter Name:** `/ktb-community/frontend/lambda-api-url`

**설정 값:**
- **EC2 프로덕션**: `"/images"` (Nginx 경유, 권장)
- **로컬 개발**: `null` (Multipart fallback)

**이유:**
- Nginx가 `https://community.ktb-waf.cloud/images` → `https://ul62gy8gxi.execute-api.ap-northeast-2.amazonaws.com`로 프록시
- Same-Origin 요청 → CORS 문제 없음
- Nginx 설정 변경 시 Parameter만 업데이트

**등록 명령어:**
```bash
# EC2 프로덕션 (권장, Nginx 경유)
aws ssm put-parameter \
  --name "/ktb-community/frontend/lambda-api-url" \
  --value "/images" \
  --type String \
  --region ap-northeast-2 \
  --overwrite

# 또는 직접 호출 (옵션)
aws ssm put-parameter \
  --name "/ktb-community/frontend/lambda-api-url" \
  --value "https://ul62gy8gxi.execute-api.ap-northeast-2.amazonaws.com/images" \
  --type String \
  --region ap-northeast-2 \
  --overwrite
```

---

## 등록 방법

### 방법 1: AWS CLI (권장)

**사전 요구사항:**
- AWS CLI 설치 (`aws --version`)
- 로컬 자격증명 설정 (`aws configure`)

**일괄 등록 스크립트:**
```bash
#!/bin/bash

# Parameter Store 일괄 등록 (Frontend)
# 사용법: chmod +x register-params.sh && ./register-params.sh

AWS_REGION="ap-northeast-2"

echo "========================================="
echo "Parameter Store 등록 시작"
echo "========================================="
echo ""

# 1. BACKEND_URL (빈 문자열)
echo "[1/2] /ktb-community/frontend/backend-url 등록..."
aws ssm put-parameter \
  --name "/ktb-community/frontend/backend-url" \
  --value "" \
  --type String \
  --region "$AWS_REGION" \
  --overwrite
echo "✓ 완료"

# 2. LAMBDA_API_URL (/images)
echo "[2/2] /ktb-community/frontend/lambda-api-url 등록..."
aws ssm put-parameter \
  --name "/ktb-community/frontend/lambda-api-url" \
  --value "/images" \
  --type String \
  --region "$AWS_REGION" \
  --overwrite
echo "✓ 완료"

echo ""
echo "========================================="
echo "모든 Parameter 등록 완료! ✅"
echo "========================================="
```

**실행:**
```bash
chmod +x register-params.sh
./register-params.sh
```

---

### 방법 2: AWS Console

1. AWS Console → Systems Manager → Parameter Store
2. 파라미터 생성 클릭
3. 다음 정보 입력:
   - **Name**: `/ktb-community/frontend/backend-url`
   - **Type**: String (SecureString 불필요, 민감 정보 아님)
   - **Value**: `""` (빈 문자열)
4. 파라미터 생성
5. LAMBDA_API_URL 반복 (Value: `/images`)

---

## IAM 권한 설정

### EC2 IAM 역할 필수 권한

**정책 이름:** `KTB-Community-Frontend-SSM-Policy`

**JSON 정책:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      "Resource": [
        "arn:aws:ssm:ap-northeast-2:*:parameter/ktb-community/frontend/*"
      ]
    }
  ]
}
```

**IAM 역할 연결:**
1. EC2 콘솔 → 인스턴스 선택 → 작업 → 보안 → IAM 역할 수정
2. `KTB-Community-EC2-Role` 선택 (또는 생성)
3. 정책 연결: `KTB-Community-Frontend-SSM-Policy`

---

## 검증 방법

### 1. AWS CLI로 확인 (로컬)

```bash
# 모든 Parameter 조회
aws ssm get-parameters-by-path \
  --path "/ktb-community/frontend" \
  --region ap-northeast-2

# 개별 Parameter 조회
aws ssm get-parameter \
  --name "/ktb-community/frontend/backend-url" \
  --query 'Parameter.Value' \
  --output text \
  --region ap-northeast-2
```

**예상 출력:**
```
# backend-url
(빈 줄, 빈 문자열)

# lambda-api-url
/images
```

---

### 2. EC2에서 확인

**SSH 접속:**
```bash
ssh -i ~/.ssh/ktb-community-key-pair.pem ubuntu@15.164.222.112
```

**IAM 역할 확인:**
```bash
# EC2 메타데이터에서 IAM 역할 확인
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/

# Parameter 조회 테스트
aws ssm get-parameter \
  --name "/ktb-community/frontend/backend-url" \
  --query 'Parameter.Value' \
  --output text \
  --region ap-northeast-2
```

---

### 3. 컨테이너에서 확인

**배포 후 확인:**
```bash
# 컨테이너 환경 변수 확인
docker exec community-frontend printenv | grep -E "BACKEND_URL|LAMBDA_API_URL"

# 예상 출력:
# BACKEND_URL=
# LAMBDA_API_URL=/images

# config.js 파일 확인
docker exec community-frontend cat /app/origin_source/static/config.js

# 예상 출력:
# window.APP_CONFIG = {
#   API_BASE_URL: '',
#   LAMBDA_API_URL: '/images'
# };
```

---

## 트러블슈팅

### 문제 1: Parameter not found

**증상:**
```
An error occurred (ParameterNotFound) when calling the GetParameter operation
```

**원인:** Parameter Store에 등록되지 않음

**해결:**
```bash
# 등록 확인
aws ssm get-parameters-by-path --path "/ktb-community/frontend" --region ap-northeast-2

# 없으면 등록
aws ssm put-parameter \
  --name "/ktb-community/frontend/backend-url" \
  --value "" \
  --type String \
  --region ap-northeast-2
```

---

### 문제 2: Access Denied

**증상:**
```
An error occurred (AccessDeniedException) when calling the GetParameter operation
```

**원인:** EC2 IAM 역할에 SSM 권한 없음

**해결:**
1. IAM 콘솔 → 역할 → `KTB-Community-EC2-Role`
2. 권한 정책 추가 → `KTB-Community-Frontend-SSM-Policy` 연결
3. EC2 재시작 불필요 (IAM 역할은 즉시 적용)

---

### 문제 3: 빈 문자열이 제대로 주입되지 않음

**증상:**
```bash
docker exec community-frontend printenv | grep BACKEND_URL
# 출력 없음
```

**원인:** 빈 문자열은 환경 변수에서 무시될 수 있음

**해결:**
```bash
# Dockerfile 기본값 확인 (빈 문자열 설정됨)
docker inspect community-frontend | jq '.[0].Config.Env'

# server.js에서 process.env.BACKEND_URL || '' 처리됨
docker logs community-frontend | grep "Generated config.js"

# 예상 출력:
# ✅ Generated config.js with BACKEND_URL=
```

---

### 문제 4: CORS 에러 (직접 API Gateway 호출 시)

**증상:**
```
Access to fetch at 'https://ul62gy8gxi.execute-api.ap-northeast-2.amazonaws.com/images'
from origin 'https://community.ktb-waf.cloud' has been blocked by CORS policy
```

**원인:** LAMBDA_API_URL을 직접 API Gateway URL로 설정

**해결:**
```bash
# Nginx 경유 방식으로 변경
aws ssm put-parameter \
  --name "/ktb-community/frontend/lambda-api-url" \
  --value "/images" \
  --type String \
  --region ap-northeast-2 \
  --overwrite

# 컨테이너 재시작
./run-docker-container.sh registry.ktb-waf.cloud/ktb-fe:latest
```

---

## 환경별 설정 요약

| 환경 | BACKEND_URL | LAMBDA_API_URL | 설명 |
|------|-------------|----------------|------|
| **로컬 개발** | `http://localhost:8080` | `null` | Express가 직접 프록시 |
| **EC2 프로덕션** | `""` (빈 문자열) | `/images` | Nginx가 라우팅 (권장) |
| **EC2 옵션** | `https://community.ktb-waf.cloud` | `https://community.ktb-waf.cloud/images` | 절대 경로 |

---

## 참고 문서

- **[CLAUDE.md](../CLAUDE.md)**: 프로젝트 개요 및 아키텍처
- **[FRONTEND_GUIDE.md](./fe/FRONTEND_GUIDE.md)**: API 연동 가이드
- **run-docker-container.sh**: EC2 배포 스크립트
- **Nginx 설정**: Path-based Routing 규칙

---

## 변경 이력

| 날짜 | 버전 | 변경 내용 |
|------|------|-----------|
| 2025-01-20 | 1.0 | 프론트엔드 Parameter Store 가이드 작성 (Nginx 라우팅 대응) |
