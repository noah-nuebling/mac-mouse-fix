**ℹ️ Mac Mouse Fix 2 사용자 참고사항**

Mac Mouse Fix 3의 출시와 함께 앱의 가격 정책이 변경되었습니다:

- **Mac Mouse Fix 2**\
계속해서 100% 무료이며, 지원도 계속할 예정입니다.\
Mac Mouse Fix 2를 계속 사용하시려면 **이 업데이트를 건너뛰세요**. Mac Mouse Fix 2의 최신 버전은 [여기](https://redirect.macmousefix.com/?target=mmf2-latest)에서 다운로드하실 수 있습니다.
- **Mac Mouse Fix 3**\
30일 무료 사용 후 소유권을 얻으려면 몇 달러가 필요합니다.\
Mac Mouse Fix 3를 사용하시려면 **지금 업데이트하세요**!

Mac Mouse Fix 3의 가격과 기능에 대해 자세히 알아보시려면 [새 웹사이트](https://macmousefix.com/)를 방문해주세요.

Mac Mouse Fix를 사용해 주셔서 감사합니다! :)

---

**ℹ️ Mac Mouse Fix 3 구매자 참고사항**

유료 전환을 모르고 실수로 Mac Mouse Fix 3로 업데이트하신 경우, [환불](https://redirect.macmousefix.com/?target=mmf-apply-for-refund)을 제공해 드리고 있습니다.

Mac Mouse Fix 2의 최신 버전은 계속해서 **완전 무료**로 제공되며, [여기](https://redirect.macmousefix.com/?target=mmf2-latest)에서 다운로드하실 수 있습니다.

불편을 끼쳐 죄송합니다. 이러한 해결책이 모두에게 만족스러우시길 바랍니다!

---

Mac Mouse Fix **3.0.5**는 여러 버그를 수정하고, 성능을 개선하며, 앱에 약간의 개선사항을 추가했습니다.\
또한 macOS 26 Tahoe와도 호환됩니다.

### 트랙패드 스크롤 시뮬레이션 개선

- 이제 스크롤 시스템이 트랙패드의 두 손가락 탭을 시뮬레이션하여 앱의 스크롤을 중지할 수 있습니다.
    - 이는 iPhone 또는 iPad 앱 실행 시 사용자가 중지하려고 해도 스크롤이 계속되는 문제를 해결합니다.
- 트랙패드에서 손가락을 떼는 동작의 일관성 없는 시뮬레이션 수정.
    - 이로 인해 일부 상황에서 최적화되지 않은 동작이 발생했을 수 있습니다.

### macOS 26 Tahoe 호환성

macOS 26 Tahoe 베타에서 앱을 사용할 수 있으며 대부분의 UI가 올바르게 작동합니다.

### 성능 향상

"스크롤 및 탐색" 제스처의 클릭 앤 드래그 성능이 개선되었습니다.\
제 테스트에서 CPU 사용량이 약 50% 감소했습니다!

**배경**

"스크롤 및 탐색" 제스처 동안, Mac Mouse Fix는 실제 마우스 커서를 고정한 채로 투명한 창에 가짜 마우스 커서를 표시합니다. 이를 통해 마우스를 얼마나 멀리 움직이든 처음 스크롤을 시작한 UI 요소에서 계속 스크롤할 수 있습니다.

성능 향상은 사용되지 않던 이 투명 창의 기본 macOS 이벤트 처리를 비활성화함으로써 달성되었습니다.

### 버그 수정

- 이제 Wacom 드로잉 태블릿의 스크롤 이벤트를 무시합니다.
    - 이전에는 Mac Mouse Fix가 Wacom 태블릿에서 불규칙한 스크롤을 유발했습니다. GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233)에서 @frenchie1980가 보고한 문제입니다. (감사합니다!)
    
- Mac Mouse Fix 3.0.4의 새로운 라이선스 시스템의 일부로 도입된 Swift Concurrency 코드가 올바른 스레드에서 실행되지 않는 버그를 수정했습니다.
    - 이로 인해 macOS Tahoe에서 충돌이 발생했으며, 라이선스 관련 산발적인 버그도 발생했을 것입니다.
- 오프라인 라이선스 디코딩 코드의 안정성을 개선했습니다.
    - 이는 Intel Mac Mini에서 오프라인 라이선스 검증이 항상 실패하게 만든 Apple API의 문제를 해결합니다. 이 문제는 모든 Intel Mac에서 발생했을 것으로 추정되며, GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356)에서 @toni20k5267이 보고한 것처럼 (감사합니다!) 3.0.4에서 이미 해결된 "무료 기간 종료" 버그가 일부 사용자에게 여전히 발생한 원인으로 보입니다.
        - "무료 기간 종료" 버그를 경험하신 분들께 죄송합니다! [여기](https://redirect.macmousefix.com/?target=mmf-apply-for-refund)에서 환불받으실 수 있습니다.

### UX 개선

- Mac Mouse Fix 활성화를 방해하는 macOS 버그에 대한 단계별 해결책을 제공하는 대화상자를 비활성화했습니다.
    - 이러한 문제는 macOS 13 Ventura와 14 Sonoma에서만 발생했습니다. 이제 이 대화상자는 관련이 있는 macOS 버전에서만 표시됩니다.
    - 또한 대화상자가 트리거되기가 더 어려워졌습니다 - 이전에는 도움이 되지 않는 상황에서도 가끔 표시되었습니다.
    
- "무료 기간 종료" 알림에 직접 "라이선스 활성화" 링크를 추가했습니다.
    - 이를 통해 Mac Mouse Fix 라이선스 활성화가 더욱 간편해졌습니다!

### 시각적 개선

- "소프트웨어 업데이트" 창의 모양을 약간 개선했습니다. 이제 macOS 26 Tahoe와 더 잘 어울립니다.
    - 이는 Mac Mouse Fix가 업데이트 처리에 사용하는 "Sparkle 1.27.3" 프레임워크의 기본 모양을 커스터마이징하여 이루어졌습니다.
- 창을 약간 더 넓게 만들어 중국어에서 About 탭 하단의 텍스트가 잘리는 문제를 해결했습니다.
- About 탭 하단의 텍스트가 약간 중앙에서 벗어나는 문제를 수정했습니다.
- Buttons 탭의 "키보드 단축키..." 옵션 아래 공간이 너무 작은 버그를 수정했습니다.

### 내부 변경사항

- "SnapKit" 프레임워크 의존성을 제거했습니다.
    - 이로 인해 앱 크기가 19.8MB에서 19.5MB로 약간 감소했습니다.
- 코드베이스의 기타 작은 개선사항들이 있습니다.

*Claude의 훌륭한 도움으로 편집되었습니다.*

---

이전 릴리스 [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4)도 확인해보세요.