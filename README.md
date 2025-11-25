# KTB 커뮤니티 프론트엔드

카카오테크 부트캠프 커뮤니티 플랫폼의 프론트엔드입니다.

🌐 **서비스 URL**: https://community.ktb-waf.cloud

## 기술 스택

- **프론트엔드**: Vanilla JavaScript, HTML, CSS
- **서버**: Express.js (정적 파일 서빙)
- **백엔드**: Spring Boot (별도 프로젝트)

## 로컬 개발

```bash
npm install
npm run dev    # 개발 모드 (자동 재시작)
npm start      # 운영 모드
```

접속: http://localhost:3000

## 프로젝트 구조

```
ktb_community_fe/
├── origin_source/static/
│   ├── css/              # 스타일시트
│   ├── js/               # JavaScript
│   └── pages/            # HTML 페이지
├── server.js             # Express 서버
└── package.json
```
