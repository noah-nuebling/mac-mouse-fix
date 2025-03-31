Mac Mouse Fix **2.2.1**은 다른 변경사항과 함께 **macOS Ventura를 완벽하게 지원**합니다.

### Ventura 지원!
Mac Mouse Fix가 이제 macOS 13 Ventura를 완벽히 지원하며 네이티브처럼 작동합니다.
GitHub 이슈 [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297)에서 Ventura 지원을 도와준 [@chamburr](https://github.com/chamburr)에게 특별히 감사드립니다.

변경 사항:

- 새로운 Ventura 시스템 설정을 반영하여 접근성 접근 권한 부여를 위한 UI 업데이트
- Ventura의 새로운 **시스템 설정 > 로그인 항목** 메뉴에서 Mac Mouse Fix가 올바르게 표시됨
- **시스템 설정 > 로그인 항목**에서 비활성화될 때 Mac Mouse Fix가 적절하게 반응함

### 이전 macOS 버전 지원 중단

안타깝게도 Apple은 macOS 13 Ventura에서 개발할 때 macOS 10.13 **High Sierra 이상** 버전에 대해서만 개발을 허용합니다.

따라서 **최소 지원 버전**이 10.11 El Capitan에서 10.13 High Sierra로 상향되었습니다.

### 버그 수정

- Mac Mouse Fix가 일부 **드로잉 태블릿**의 스크롤 동작을 변경하는 문제를 수정했습니다. GitHub 이슈 [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249)를 참조하세요.
- 'A' 키를 포함한 **키보드 단축키**를 기록할 수 없는 문제를 수정했습니다. GitHub 이슈 [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275)를 해결했습니다.
- 비표준 키보드 레이아웃 사용 시 일부 **버튼 재매핑**이 제대로 작동하지 않는 문제를 수정했습니다.
- 'Bundle ID'가 없는 앱을 추가할 때 '**앱별 설정**'에서 발생하는 충돌을 수정했습니다. GitHub 이슈 [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289)에 도움이 될 수 있습니다.
- 이름이 없는 앱을 '**앱별 설정**'에 추가하려 할 때 발생하는 충돌을 수정했습니다. GitHub 이슈 [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241)을 해결했습니다. 문제 해결에 큰 도움을 준 [jeongtae](https://github.com/jeongtae)에게 특별히 감사드립니다!
- 기타 작은 버그 수정 및 내부 개선 사항들이 있습니다.