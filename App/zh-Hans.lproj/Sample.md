# 欢迎使用 Velmo Viewer

在 Finder 里选中任意 `.md` 文件，按下**空格**，就能看到这样排好版的文章。

## 支持的内容

- **粗体**、*斜体*、~~删除线~~、`行内代码` 和 [链接](https://velmo.ink)
- [x] 任务列表
- [ ] 脚注[^1]、表格、数学公式

> 写作是思考的延伸。

```swift
func greet(_ name: String) -> String {
    return "Hello, \(name)!" // 代码高亮
}
```

| 快捷键 | 作用 |
| ------ | ---- |
| 空格   | 快速查看 |
| ⌥ 空格 | 全屏查看 |

行内公式 $e^{i\pi} + 1 = 0$，以及块级公式：

$$
\int_0^1 x^2\,dx = \frac{1}{3}
$$

ECharts 图表，代码块里写 JSON 格式的 option：

```echarts
{
  "tooltip": {},
  "xAxis": { "type": "category", "data": ["周一", "周二", "周三", "周四", "周五", "周六", "周日"] },
  "yAxis": { "type": "value" },
  "series": [{ "name": "字数", "type": "bar", "data": [820, 1320, 960, 1500, 1100, 600, 300] }]
}
```

Mermaid 流程图、时序图等：

```mermaid
flowchart LR
  A[在 Finder 选中 .md] --> B{按空格}
  B --> C[排好版的文章]
  B --> D[图表和流程图]
```

[^1]: 脚注会显示在文末。
