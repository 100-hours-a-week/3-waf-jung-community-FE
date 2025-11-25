FROM node:18-alpine

WORKDIR /app

# 의존성 파일 복사 (package-lock.json 포함, 레이어 캐싱 최적화)
COPY package*.json ./

# 프로덕션 의존성만 설치 (devDependencies 제외)
# - nodemon 제외: 개발용 파일 변경 감지 도구 (프로덕션 불필요)
# - 이미지 크기 감소: 200MB → 190MB (10MB 절약)
RUN npm ci --only=production

# 소스 코드 복사 (node 사용자 권한으로)
COPY --chown=node:node . .

# node 사용자로 전환 (보안: root 사용 방지)
# - node:18-alpine 이미지에 기본 포함된 사용자 (UID 1000)
# - 컨테이너 탈출 시 호스트 피해 최소화
USER node

ENV NODE_ENV=production \
    PORT=3000 \
    BACKEND_URL= \
    LAMBDA_API_URL=/images

# 컨테이너가 수신 대기할 포트를 작성 : 문서화
EXPOSE 3000

CMD ["node", "server.js"]