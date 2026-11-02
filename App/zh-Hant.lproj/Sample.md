# 歡迎使用 Velmo Viewer

在 Finder 中選取任意 `.md` 檔案，按下**空白鍵**，就能看到這樣排好版的文章。

## 支援的內容

- **粗體**、*斜體*、~~刪除線~~、`行內程式碼` 和 [連結](https://velmo.ink)
- [x] 待辦清單
- [ ] 註腳[^1]、表格、數學公式

> 寫作是思考的延伸。

```swift
func greet(_ name: String) -> String {
    return "Hello, \(name)!" // 語法高亮
}
```

| 快速鍵 | 作用 |
| ------ | ---- |
| 空白鍵   | 快速查看 |
| ⌥ 空白鍵 | 全螢幕查看 |

行內公式 $e^{i\pi} + 1 = 0$，以及區塊公式：

$$
\int_0^1 x^2\,dx = \frac{1}{3}
$$

ECharts 圖表，程式碼區塊裡寫 JSON 格式的 option：

```echarts
{
  "tooltip": {},
  "xAxis": { "type": "category", "data": ["週一", "週二", "週三", "週四", "週五", "週六", "週日"] },
  "yAxis": { "type": "value" },
  "series": [{ "name": "字數", "type": "bar", "data": [820, 1320, 960, 1500, 1100, 600, 300] }]
}
```

Mermaid 流程圖、循序圖等：

```mermaid
flowchart LR
  A[在 Finder 選取 .md] --> B{按空白鍵}
  B --> C[排好版的文章]
  B --> D[圖表和流程圖]
```

[^1]: 註腳會顯示在文末。
