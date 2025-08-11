**ℹ️ Mac Mouse Fix 2 사용자 참고사항**

Mac Mouse Fix 3의 출시와 함께 앱의 가격 정책이 변경되었습니다:

- **Mac Mouse Fix 2**\
100% 무료로 유지되며, 계속해서 지원할 예정입니다.\
Mac Mouse Fix 2를 계속 사용하시려면 **이 업데이트를 건너뛰세요**. Mac Mouse Fix 2의 최신 버전은 [여기](https://redirect.macmousefix.com/?target=mmf2-latest)에서 다운로드하실 수 있습니다.
- **Mac Mouse Fix 3**\
30일 무료 체험, 소유권은 몇 달러의 비용이 듭니다.\
Mac Mouse Fix 3를 사용하시려면 **지금 업데이트하세요**!

Mac Mouse Fix 3의 가격과 기능에 대해 [새 웹사이트](https://macmousefix.com/)에서 자세히 알아보실 수 있습니다.

Mac Mouse Fix를 사용해 주셔서 감사합니다! :)

---

**ℹ️ Mac Mouse Fix 3 구매자 참고사항**

유료 버전인 것을 모르고 실수로 Mac Mouse Fix 3로 업데이트하신 경우, [환불](https://redirect.macmousefix.com/?target=mmf-apply-for-refund)을 제공해 드리고자 합니다.

Mac Mouse Fix 2의 최신 버전은 계속해서 **완전 무료**로 제공되며, [여기](https://redirect.macmousefix.com/?target=mmf2-latest)에서 다운로드하실 수 있습니다.

불편을 끼쳐 죄송합니다. 이러한 해결책이 모두에게 괜찮기를 바랍니다!

---

Mac Mouse Fix **3.0.6**은 '뒤로' 및 '앞으로' 기능의 앱 호환성을 개선하고 여러 버그와 문제를 해결했습니다.

### '뒤로' 및 '앞으로' 호환성 개선

'뒤로' 및 '앞으로' 마우스 버튼 매핑이 이제 **더 많은 앱에서 작동**합니다:
- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed 및 기타 코드 에디터
- Preview, Notes, 시스템 설정, App Store, Music, TV, Books, Freeform 등 많은 Apple 기본 앱
- Adobe Acrobat
- Zotero
- 기타 여러 앱!

이 구현은 [LinearMouse](https://github.com/linearmouse/linearmouse)의 훌륭한 '유니버설 뒤로 및 앞으로' 기능에서 영감을 받았습니다. LinearMouse가 지원하는 모든 앱을 지원해야 합니다.\
또한 시스템 설정, App Store, Apple Notes, Adobe Acrobat와 같이 일반적으로 키보드 단축키로 뒤로/앞으로 이동해야 하는 앱들도 지원합니다. Mac Mouse Fix는 이러한 앱들을 감지하고 적절한 키보드 단축키를 시뮬레이션합니다.

[GitHub 이슈에서 요청된](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) 모든 앱이 이제 지원됩니다! (피드백 감사합니다!)
아직 작동하지 않는 앱을 발견하시면 [기능 요청](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request)을 통해 알려주세요.

### '스크롤이 간헐적으로 작동하지 않는' 버그 해결

일부 사용자들이 **부드러운 스크롤이 무작위로 작동을 멈추는** [문제](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22)를 경험했습니다.

제가 직접 문제를 재현하지는 못했지만, 잠재적인 해결책을 구현했습니다:

이제 디스플레이 동기화 설정이 실패할 경우 앱이 여러 번 재시도합니다.\
여러 번 시도 후에도 작동하지 않으면 앱은:
- 문제 해결을 위해 'Mac Mouse Fix Helper' 백그라운드 프로세스를 재시작합니다
- 버그 진단에 도움이 될 수 있는 충돌 보고서를 생성합니다

이제 문제가 완전히 해결되었기를 바랍니다! 그렇지 않다면 [버그 리포트](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report)나 [이메일](http://redirect.macmousefix.com/?target=mailto-noah)로 알려주세요.

### 프리스핀 스크롤 휠 동작 개선

이제 Mac Mouse Fix는 MX Master 마우스(또는 프리스핀 스크롤 휠이 있는 다른 마우스)에서 스크롤 휠을 자유롭게 회전시킬 때 **더 이상 스크롤 속도를 자동으로 높이지 않습니다**.

일반 스크롤 휠에서는 이 '스크롤 가속' 기능이 유용하지만, 프리스핀 스크롤 휠에서는 오히려 제어를 어렵게 만들 수 있습니다.

**참고:** 현재 Mac Mouse Fix는 MX Master를 포함한 대부분의 로지텍 마우스와 완벽하게 호환되지 않습니다. 완전한 지원을 추가할 계획이지만 시간이 좀 걸릴 것 같습니다. 그동안에는 로지텍 지원이 있는 최고의 서드파티 드라이버로 [SteerMouse](https://plentycom.jp/en/steermouse/)를 추천드립니다.

### 버그 수정

- Mac Mouse Fix가 시스템 설정에서 이전에 비활성화된 키보드 단축키를 다시 활성화하는 문제 수정
- '라이선스 활성화' 클릭 시 발생하는 충돌 수정
- '라이선스 활성화' 클릭 직후 '취소'를 클릭할 때 발생하는 충돌 수정 (보고해 주셔서 감사합니다, Ali!)
- Mac에 디스플레이가 연결되지 않은 상태에서 Mac Mouse Fix를 사용하려 할 때 발생하는 충돌 수정
- 앱의 탭 전환 시 발생하는 메모리 누수 및 기타 내부 문제 수정

### 시각적 개선

- [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)에서 발생한 About 탭이 때때로 너무 높게 표시되는 문제 수정
- 중국어에서 '무료 기간 종료' 알림의 텍스트가 잘리는 문제 수정
- 입력 기록 후 '+' 필드의 그림자에 발생하는 시각적 결함 수정
- '라이선스 키 입력' 화면에서 플레이스홀더 텍스트가 중앙에서 벗어나 표시되는 드문 결함 수정
- '라이선스 키 입력' 화면에서 Touch Bar 텍스트 자동완성 비활성화
- 다크/라이트 모드 전환 후 앱에 표시되는 일부 기호의 색상이 잘못되는 문제 수정

### 기타 개선사항

- 탭 전환 애니메이션 등 일부 애니메이션의 효율성 개선
- 기타 여러 내부 개선사항

*Claude의 훌륭한 도움으로 편집되었습니다.*

---

이전 릴리스 [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)도 확인해 보세요.