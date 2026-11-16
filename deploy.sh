#!/bin/bash
# 오늘 관제판 배포 스크립트
# 사용: bash deploy.sh
# 1) 저장소 존재 확인 → 2) push → 3) GitHub Pages 활성화 → 4) 200 OK 검증
set -u
OWNER=tellrza-design
REPO=daily-dashboard
URL="https://${OWNER}.github.io/${REPO}/"
cd "$(dirname "$0")" || exit 1

echo "① 저장소 확인"
if ! gh api "/repos/${OWNER}/${REPO}" >/dev/null 2>&1; then
  echo "   ✗ ${OWNER}/${REPO} 가 없습니다 (404)."
  echo "     → github.com/new 에서 public 저장소 '${REPO}' 를 만들고(README 체크 해제) 다시 실행하세요."
  exit 2
fi
echo "   ✓ 존재"

echo "② main 푸시"
git push -u origin main || { echo "   ✗ push 실패 (앱이 이 저장소에 접근 권한이 없을 수 있음: github.com/apps/pickle/installations/new)"; exit 3; }
echo "   ✓ 푸시 완료"

echo "③ GitHub Pages 활성화"
if gh api "/repos/${OWNER}/${REPO}/pages" >/dev/null 2>&1; then
  echo "   Pages 이미 활성 — 설정 갱신 시도"
  gh api -X PUT "/repos/${OWNER}/${REPO}/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
    && echo "   ✓ 갱신" || echo "   · 갱신 생략(이미 main/root)"
else
  gh api -X POST "/repos/${OWNER}/${REPO}/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
    && echo "   ✓ 활성화 요청" || echo "   ✗ 활성화 실패 (앱에 Pages 권한이 없으면 GitHub 저장소 Settings → Pages 에서 main/root 선택)"
fi

echo "④ 배포 확인: ${URL}"
for i in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "${URL}?v=${i}" 2>/dev/null)
  echo "   시도 ${i}: HTTP ${code}"
  [ "${code}" = "200" ] && { echo "   ✓ 배포 완료 → ${URL}"; exit 0; }
  sleep 10
done
echo "   ✗ 5분 내 200 미확인 — Pages 빌드 상태: gh api /repos/${OWNER}/${REPO}/pages/builds/latest"
exit 4
