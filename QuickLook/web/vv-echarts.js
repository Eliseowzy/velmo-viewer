// 把 ```echarts 代码块渲染成图表。代码块里写 ECharts 的 option（JSON）。
// echarts.min.js 是 npm 包 echarts（6.1.0）的 dist/echarts.min.js，升级时直接替换。
// 只有文档里有 echarts 代码块时 MarkdownRenderer 才会加载它，echarts.min.js 也是这时才读。
// 只认 JSON，不执行代码块里的 JS：空格预览打开的是任意文件，不能让文档在预览里跑脚本。

import { t } from './vv-i18n.js';

const charts = [];
const dark = matchMedia('(prefers-color-scheme: dark)');

function loadEcharts() {
  if (window.echarts) return Promise.resolve(window.echarts);
  return new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = new URL('echarts.min.js', import.meta.url).href;
    s.onload = () => resolve(window.echarts);
    s.onerror = () => reject(new Error(t('loadFailed', { file: 'echarts.min.js' })));
    document.head.append(s);
  });
}

function addStyle() {
  if (document.getElementById('vv-echarts-style')) return;
  const s = document.createElement('style');
  s.id = 'vv-echarts-style';
  s.textContent = `
.velmo-article .vv-echarts { width: 100%; height: 400px; margin: 0 0 1em; }
.velmo-article .vv-echarts-error { color: #C0392B; font-size: .86em; margin: -.6em 0 1em; }
@media (prefers-color-scheme: dark) { .velmo-article .vv-echarts-error { color: #F08A7E; } }
`;
  document.head.append(s);
}

function showError(pre, e) {
  const err = document.createElement('div');
  err.className = 'vv-echarts-error';
  err.textContent = t('error', { name: 'ECharts', message: e.message });
  pre.after(err);
}

// 去掉各层的 link / sublink（标题、treemap 和 sunburst 的节点）：点击时 ECharts 用 window.open 打开，
// 写成 javascript: 就会在预览页里执行；正常链接在预览里也打不开
function dropLinks(value) {
  if (Array.isArray(value)) return value.map(dropLinks);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.entries(value)
    .filter(([k]) => k !== 'link' && k !== 'sublink')
    .map(([k, v]) => [k, dropLinks(v)]));
}

// tooltip 的 formatter 和 toolbox 的数据视图会把字符串当 HTML 插进页面，而 Markdown 里的原始 HTML 渲染时是转义掉的。
// tooltip 改成画在图里的富文本，toolbox 去掉（预览里也用不上），免得文档借图表往页面里塞 HTML
function sanitize(option) {
  const { toolbox, ...rest } = dropLinks(option);
  const tooltip = (t) => (t && typeof t === 'object' ? { ...t, renderMode: 'richText' } : t);
  if (rest.tooltip) rest.tooltip = Array.isArray(rest.tooltip) ? rest.tooltip.map(tooltip) : tooltip(rest.tooltip);
  return rest;
}

function init(echarts, item) {
  item.chart?.dispose();
  item.chart = echarts.init(item.el, dark.matches ? 'dark' : null, { renderer: 'svg' });
  item.chart.setOption({ backgroundColor: 'transparent', ...item.option });
}

export async function render() {
  const blocks = [...document.querySelectorAll('.velmo-article pre > code.language-echarts')];
  if (!blocks.length) return;
  addStyle();
  const echarts = await loadEcharts();
  for (const code of blocks) {
    const pre = code.parentElement;
    let option;
    try {
      option = JSON.parse(code.textContent);
      if (!option || typeof option !== 'object' || Array.isArray(option)) throw new Error(t('notObject'));
    } catch (e) {
      showError(pre, e);
      continue;
    }
    const el = document.createElement('div');
    el.className = 'vv-echarts';
    pre.replaceWith(el);
    const item = { el, option: sanitize(option), chart: null };
    charts.push(item);
    try {
      init(echarts, item);
    } catch (e) {
      item.chart?.dispose();
      charts.splice(charts.indexOf(item), 1);
      el.replaceWith(pre);
      showError(pre, e);
    }
  }
}

// 切换主题（跟随系统或在设置里改）时用对应的配色重画；窗口变宽变窄时跟着缩放
dark.addEventListener('change', () => {
  for (const item of charts) init(window.echarts, item);
});
new ResizeObserver(() => {
  for (const item of charts) item.chart?.resize();
}).observe(document.documentElement);
