# MemoryGuard

MemoryGuard는 macOS 메뉴 막대에서 메모리 사용량을 보여주는 앱입니다.

## 다운로드

1. 이 저장소의 **Releases** 페이지로 이동합니다.
2. 최신 버전의 `MemoryGuard-버전.zip` 파일을 다운로드합니다.
3. 다운로드한 zip 파일을 압축 해제합니다.

## 적용(설치) 및 실행

1. 압축 해제 후 나온 `MemoryGuard.app`을 `Applications` 폴더로 이동합니다.
2. `Applications`에서 `MemoryGuard.app`을 실행합니다.
3. 처음 실행 시 macOS 보안 경고가 나오면:
   - `시스템 설정 > 개인정보 보호 및 보안`으로 이동
   - `확인 없이 열기`(또는 유사 버튼)를 눌러 실행 허용

실행 후 메뉴 막대에서 MemoryGuard 아이콘을 눌러 메모리 상태를 확인할 수 있습니다.

## 터미널 설치/업데이트 가이드

`git pull`은 이미 내려받은 저장소에서만 동작합니다.
즉, **처음 설치 1회는 `git clone`이 필요**합니다.

```bash
git clone https://github.com/gh7035/MemoryGuard.git
cd MemoryGuard
./build_app.sh
open "./MemoryGuard.app"
```

이후 업데이트부터는 `git pull`만 실행하면 됩니다.

```bash
cd "/경로/MemoryGuard"
git pull
./build_app.sh
open "./MemoryGuard.app"
```
