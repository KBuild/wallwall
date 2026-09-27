# WALLWALL

[English](README.en.md) · [요구 사항](Docs/REQUIREMENT.md) · [고지 사항](Docs/DISCLAIMER.md) · [서드파티 도구](Docs/THIRD_PARTY.md)

개인이 보유한 Windows `WallpaperEV`를 macOS Unity 앱으로 복원하고 MP4로 내보내는 스크립트입니다. 대상은 **2026 에버리스 1주년 기념 광고** 리워드 **「반응형 월페이퍼-TUS 작가님」**이며, 다른 작품의 호환성은 보장하지 않습니다.

AI의 도움으로 개발했습니다(*vibe coding*).

**사용 전:** 소유권·라이선스·배포 조건을 [고지 사항](Docs/DISCLAIMER.md)에서 읽어 주세요.

## 실행

1. [요구 사항](Docs/REQUIREMENT.md)의 도구와 라이선스를 준비합니다.
2. 이용 권한이 있는 `WallPaper.exe`와 `WallPaper_Data/`를 `WallpaperEV/`에 놓습니다.
3. 저장소 루트에서 실행합니다.

```sh
python3 Scripts/generate-port.py
Scripts/build-macos.sh
Scripts/export-video.sh
```

결과: `Builds/WALLWALL.mp4` — 1920×1080, 30초, 30 FPS, 무음. 원하는 macOS 동영상 배경화면 앱에서 열면 됩니다. 특정 배경화면 앱은 필수가 아닙니다.

출력 중에는 창을 닫거나 크기를 바꾸거나 조작하지 마세요. 출력은 영상 길이보다 오래 걸릴 수 있습니다. 기존 MP4는 덮어쓰지 않으므로 `WALLWALL_VIDEO_PATH`로 다른 경로를 지정하세요. 길이는 `WALLWALL_VIDEO_SECONDS`로 변경합니다.

입력 폴더는 `--source`로 지정합니다. `generate-port.py --force`는 생성된 `Port/`를 교체합니다.

## 움직이는 바탕화면: Unity 앱

```sh
Scripts/run-wallpaper.sh
# Builds/WALLWALL.app을 직접 열어도 기본값은 배경 모드입니다.
# 배경화면 배치 없이 일반 창으로 실행:
WALLWALL_WINDOWED=1 Scripts/run-wallpaper.sh
```

앱은 Unity 창 하나를 바탕화면 아이콘 뒤에 놓습니다. Unity가 없는 다른 디스플레이에는 같은 프로세스가 `Builds/WALLWALL.mp4`를 반복하는 클릭 통과 창을 띄웁니다. **WW → MP4 fallback**은 영상 전용 디스플레이 수를 표시합니다. 이 영상에는 실시간 포인터 반응이 없습니다. 앱과 MP4를 `Builds/`에 함께 두세요.

**WW → Interactive Display**에서 실시간 반응을 사용할 화면을 선택하면 재실행 후에도 유지됩니다. Unity 화면에서는 **WW → Pointer Trigger**로 호버·드래그 반응을 고르고 랜덤 반응 메뉴로 자동 재생을 설정합니다. 호버는 앱 포커스·클릭 없이 보이는 반응 영역의 커서를 따르며, 같은 영역 안에서 움직여도 대기 시간이 유지됩니다. 호버 모드는 전역 이벤트 감시를 쓰지 않고, 드래그 모드는 왼쪽 버튼 누름·뗌만 감시합니다. 다른 앱 창이 포인터 위치를 덮으면 반응을 억제합니다. 직접 입력하려면 **Interaction Mode**를 켜고 Escape로 배경 모드에 돌아옵니다.

## 화면 보호기 후보

```sh
Scripts/build-saver.sh
cp -R Builds/WALLWALL.saver "$HOME/Library/Screen Savers/"
```

시스템 설정 → 배경화면 → 화면 보호기에서 WALLWALL을 선택합니다. 번들에는 MP4가 포함되며 별도 영상 플레이어가 필요하지 않습니다. 화면 보호기 기능은 실험적이며 시스템 설정에서 작동하지 않을 수 있습니다.

## 범위와 라이선스

- 움직이는 잠금 화면은 지원하지 않습니다.
- 새 `Scripts/` 코드는 [GPLv3](LICENSE)입니다. 작품과 외부 도구에는 각각의 권리·약관이 적용됩니다. 원본·생성 프로젝트·빌드는 Git에서 제외합니다.
