Mac Mouse Fix **3.0.4**는 개인정보 보호, 효율성 및 안정성이 향상되었습니다.\
새로운 오프라인 라이선스 시스템을 도입하고 여러 중요한 버그를 수정했습니다.

### 향상된 개인정보 보호 및 효율성

3.0.4는 인터넷 연결을 최소화하는 새로운 오프라인 라이선스 인증 시스템을 도입했습니다.\
이를 통해 개인정보 보호가 강화되고 컴퓨터 시스템 리소스가 절약됩니다.\
라이선스가 있는 경우 이제 앱이 100% 오프라인으로 작동합니다!

<details>
<summary><b>자세히 보기</b></summary>
이전 버전에서는 매 실행 시마다 온라인으로 라이선스를 확인했기 때문에 제3자 서버(GitHub 및 Gumroad)에 연결 로그가 저장될 수 있었습니다. 새로운 시스템은 불필요한 연결을 제거하여 최초 라이선스 활성화 후에는 로컬 라이선스 데이터가 손상된 경우에만 인터넷에 연결합니다.
<br><br>
제가 개인적으로 사용자 행동을 기록한 적은 없지만, 이전 시스템에서는 이론적으로 제3자 서버가 IP 주소와 연결 시간을 기록할 수 있었습니다. Gumroad는 라이선스 키를 기록하고 Mac Mouse Fix 구매 시 수집한 개인 정보와 연관시킬 수 있었습니다.
<br><br>
원래 라이선스 시스템을 만들 때는 이러한 미묘한 개인정보 문제를 고려하지 않았지만, 이제 Mac Mouse Fix는 가능한 한 가장 사적이고 인터넷이 필요 없는 앱이 되었습니다!
<br><br>
<a href=https://gumroad.com/privacy>Gumroad의 개인정보 보호정책</a>과 제가 작성한 <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub 댓글</a>도 참고해 주세요.

</details>

### 버그 수정

- '스페이스 및 Mission Control'에 '클릭 앤 드래그'를 사용할 때 macOS가 가끔 멈추는 버그를 수정했습니다.
- Mac Mouse Fix의 'Mission Control'과 같은 '클릭' 동작을 사용할 때 시스템 설정의 키보드 단축키가 가끔 삭제되는 버그를 수정했습니다.
- 앱을 이미 구매한 사용자에게 '무료 사용 기간이 만료되었습니다' 알림이 표시되며 앱이 작동을 멈추는 [버그](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22)를 수정했습니다.
    - 이 버그를 경험하신 분들께 진심으로 사과드립니다. [여기서](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund) 환불을 신청하실 수 있습니다.
- 앱이 메인 창을 가져오는 방식을 개선하여 '라이선스 활성화' 화면이 가끔 나타나지 않는 버그가 해결되었을 수 있습니다.

### 사용성 개선

- '라이선스 활성화' 화면의 텍스트 필드에 공백과 줄바꿈을 입력할 수 없게 만들었습니다.
    - Gumroad 이메일에서 라이선스 키를 복사할 때 보이지 않는 줄바꿈이 실수로 선택되기 쉬워 혼란을 주는 경우가 많았습니다.
- 이 업데이트 노트는 영어를 사용하지 않는 사용자를 위해 자동으로 번역됩니다(Claude 제공). 도움이 되길 바랍니다! 문제가 있다면 알려주세요. 이는 제가 지난 1년간 개발해온 새로운 번역 시스템의 첫 모습입니다.

### macOS 10.14 Mojave (비공식) 지원 중단

Mac Mouse Fix 3는 공식적으로 macOS 11 Big Sur 이상을 지원합니다. 하지만 일부 오류와 그래픽 문제를 감수할 수 있는 사용자의 경우 Mac Mouse Fix 3.0.3 이하 버전을 macOS 10.14.4 Mojave에서도 사용할 수 있었습니다.

Mac Mouse Fix 3.0.4는 이 지원을 중단하고 이제 **macOS 10.15 Catalina가 필요합니다**.\
불편을 끼쳐 죄송합니다. 이 변경으로 최신 Swift 기능을 사용하여 향상된 라이선스 시스템을 구현할 수 있었습니다. Mojave 사용자는 계속해서 Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) 또는 [Mac Mouse Fix 2의 최신 버전](https://redirect.macmousefix.com/?target=mmf2-latest)을 사용할 수 있습니다. 모든 분께 좋은 해결책이 되길 바랍니다.

### 내부 개선사항

- Mac Mouse Fix의 설정 파일을 사람이 읽고 편집할 수 있게 유지하면서 더 강력한 데이터 모델링을 가능하게 하는 새로운 'MFDataClass' 시스템을 구현했습니다.
- Gumroad 외의 결제 플랫폼 추가를 지원하도록 구축했습니다. 따라서 향후 현지화된 결제가 가능해지고 다양한 국가에서 앱을 판매할 수 있게 될 것입니다.
- 재현하기 어려운 버그를 경험하는 사용자를 위해 더 효과적인 "디버그 빌드"를 만들 수 있도록 로깅을 개선했습니다.
- 기타 여러 가지 작은 개선 사항과 정리 작업이 있었습니다.

*Claude의 훌륭한 도움으로 편집되었습니다.*

---

이전 릴리스 [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3)도 확인해 보세요.