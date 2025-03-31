Mac Mouse Fix **2.2.4**가 이제 공증되었습니다! 또한 작은 버그 수정과 기타 개선 사항이 포함되어 있습니다.

### **공증**

Mac Mouse Fix 2.2.4가 이제 Apple의 '공증'을 받았습니다. 이는 앱을 처음 실행할 때 Mac Mouse Fix가 잠재적으로 '악성 소프트웨어'라는 메시지가 더 이상 표시되지 않는다는 것을 의미합니다.

#### 배경

앱 공증에는 연간 100달러의 비용이 듭니다. Mac Mouse Fix와 같은 무료 오픈소스 소프트웨어에 적대적이고, Apple이 iPhone이나 iPad처럼 Mac을 통제하고 제한하는 위험한 단계라고 느껴져서 항상 반대했습니다. 하지만 공증이 없어서 [앱 실행의 어려움](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114)과 심지어 [새 버전을 출시할 때까지 아무도 앱을 사용할 수 없는 상황](https://github.com/noah-nuebling/mac-mouse-fix/issues/95)과 같은 다른 문제들이 발생했습니다.

Mac Mouse Fix 3는 수익화되었기 때문에, 앱 공증을 위해 연간 100달러를 지불하는 것이 마침내 적절하다고 생각했습니다. ([자세히 알아보기](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
이제 Mac Mouse Fix 2도 공증을 받게 되어, 더 쉽고 안정적인 사용자 경험을 제공할 수 있게 되었습니다.

### **버그 수정**

- 화면 녹화 중이나 [DisplayLink](https://www.synaptics.com/products/displaylink-graphics) 소프트웨어 사용 중에 '클릭 앤 드래그' 동작을 사용할 때 커서가 사라졌다가 다른 위치에 나타나는 문제를 수정했습니다.
- macOS 10.14 Mojave 및 이전 macOS 버전에서 Mac Mouse Fix를 활성화하는 문제를 수정했습니다.
- 메모리 관리를 개선하여, 컴퓨터에서 마우스를 분리할 때 발생하는 'Mac Mouse Fix Helper' 앱의 충돌 문제를 잠재적으로 해결했습니다. 토론 [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771)을 참조하세요.

### **기타 개선 사항**

- Mac Mouse Fix의 새 버전이 있음을 알리는 창이 이제 JavaScript를 지원합니다. 이를 통해 업데이트 노트가 더 보기 좋고 읽기 쉬워졌습니다. 예를 들어, 업데이트 노트에서 이제 [Markdown 알림](https://github.com/orgs/community/discussions/16925) 등을 표시할 수 있습니다.
- "Mac Mouse Fix Helper에 접근성 접근 권한 부여" 화면에서 https://macmousefix.com/about/ 페이지로의 링크를 제거했습니다. About 페이지가 더 이상 존재하지 않고 현재는 [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix)로 대체되었기 때문입니다.
- 이 릴리스에는 이제 Mac Mouse Fix 2.2.4의 충돌 보고서를 디코딩하는 데 사용할 수 있는 dSYM 파일이 포함되어 있습니다.
- 일부 내부 정리 및 개선이 이루어졌습니다.

---

이전 릴리스 [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3)도 확인해보세요.