# Velmo Viewer에 오신 것을 환영합니다

Finder에서 `.md` 파일을 선택하고 **스페이스 바**를 누르면 이렇게 깔끔하게 정리된 글을 볼 수 있습니다.

## 지원하는 내용

- **굵게**, *기울임*, ~~취소선~~, `인라인 코드`, [링크](https://velmo.ink)
- [x] 할 일 목록
- [ ] 각주[^1], 표, 수식

> 글쓰기는 생각의 연장이다.

```swift
func greet(_ name: String) -> String {
    return "Hello, \(name)!" // 구문 강조
}
```

| 단축키 | 동작 |
| ------ | ---- |
| 스페이스   | 훑어보기 |
| ⌥ 스페이스 | 전체 화면으로 보기 |

인라인 수식 $e^{i\pi} + 1 = 0$, 그리고 블록 수식:

$$
\int_0^1 x^2\,dx = \frac{1}{3}
$$

ECharts 차트. 코드 블록에 JSON 형식의 option을 씁니다:

```echarts
{
  "tooltip": {},
  "xAxis": { "type": "category", "data": ["월", "화", "수", "목", "금", "토", "일"] },
  "yAxis": { "type": "value" },
  "series": [{ "name": "글자 수", "type": "bar", "data": [820, 1320, 960, 1500, 1100, 600, 300] }]
}
```

Mermaid 순서도, 시퀀스 다이어그램 등:

```mermaid
flowchart LR
  A[Finder에서 .md 선택] --> B{스페이스 바 누르기}
  B --> C[깔끔하게 정리된 글]
  B --> D[차트와 다이어그램]
```

[^1]: 각주는 문서 끝에 표시됩니다.
