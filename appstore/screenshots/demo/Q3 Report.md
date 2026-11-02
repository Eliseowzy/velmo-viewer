# Q3 Growth Report

Weekly active readers grew **38%** this quarter. Retention is measured week over week:

$$
R_t = \frac{|U_t \cap U_{t-1}|}{|U_{t-1}|} \qquad \text{target: } R_t \ge 0.72
$$

## Readers per week

```echarts
{
  "tooltip": {},
  "grid": { "left": 40, "right": 16, "top": 24, "bottom": 28 },
  "xAxis": { "type": "category", "data": ["W1","W2","W3","W4","W5","W6","W7","W8","W9","W10","W11","W12"] },
  "yAxis": { "type": "value" },
  "series": [{ "type": "bar", "data": [820, 932, 901, 1034, 1190, 1330, 1320, 1452, 1510, 1630, 1702, 1890], "itemStyle": { "borderRadius": [4,4,0,0] } }]
}
```
