// 把 ```mermaid 代码块渲染成图。
// mermaid.min.js 是 npm 包 mermaid（12.2.0）的 dist/mermaid.min.js，升级时直接替换。
// 只有文档里有 mermaid 代码块时 MarkdownRenderer 才会加载它，mermaid.min.js 也是这时才读。
// securityLevel 用 strict：标签里的 HTML 会被清理，click 回调和链接不生效，免得文档借图往页面里塞脚本。

import { t } from './vv-i18n.js';

const diagrams = [];
const dark = matchMedia('(prefers-color-scheme: dark)');
let seq = 0;

function loadMermaid() {
  if (window.mermaid) return Promise.resolve(window.mermaid);
  return new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = new URL('mermaid.min.js', import.meta.url).href;
    s.onload = () => resolve(window.mermaid);
    s.onerror = () => reject(new Error(t('loadFailed', { file: 'mermaid.min.js' })));
    document.head.append(s);
  });
}

function addStyle() {
  if (document.getElementById('vv-mermaid-style')) return;
  const s = document.createElement('style');
  s.id = 'vv-mermaid-style';
  s.textContent = `
.velmo-article .vv-mermaid { margin: 0 0 1em; text-align: center; overflow-x: auto; }
.velmo-article .vv-mermaid svg { max-width: 100%; height: auto; }
.velmo-article .vv-mermaid-error { color: #C0392B; font-size: .86em; margin: -.6em 0 1em; white-space: pre-wrap; }
@media (prefers-color-scheme: dark) { .velmo-article .vv-mermaid-error { color: #F08A7E; } }
`;
  document.head.append(s);
}

function configure(mermaid) {
  mermaid.initialize({
    startOnLoad: false,
    securityLevel: 'strict',
    theme: dark.matches ? 'dark' : 'default',
    fontFamily: getComputedStyle(document.querySelector('.velmo-article')).fontFamily,
  });
}

function showError(pre, e) {
  const err = document.createElement('div');
  err.className = 'vv-mermaid-error';
  // mermaid 的语法错误信息很长，只留第一段
  err.textContent = t('error', { name: 'Mermaid', message: String(e?.message ?? e).split('\n\n')[0] });
  pre.after(err);
}

async function draw(mermaid, item) {
  const { svg } = await mermaid.render(`vv-mermaid-${++seq}`, item.source);
  item.el.innerHTML = svg;
}

export async function render() {
  const blocks = [...document.querySelectorAll('.velmo-article pre > code.language-mermaid')];
  if (!blocks.length) return;
  addStyle();
  const mermaid = await loadMermaid();
  configure(mermaid);
  for (const code of blocks) {
    const pre = code.parentElement;
    const item = { el: document.createElement('div'), source: code.textContent };
    item.el.className = 'vv-mermaid';
    try {
      await draw(mermaid, item);
    } catch (e) {
      // 出错时 mermaid 会在 body 里留下一个临时节点
      document.getElementById(`dvv-mermaid-${seq}`)?.remove();
      showError(pre, e);
      continue;
    }
    pre.replaceWith(item.el);
    diagrams.push(item);
  }
}

// 切换主题（跟随系统或在设置里改）时用对应的配色重画
dark.addEventListener('change', async () => {
  if (!diagrams.length) return;
  configure(window.mermaid);
  for (const item of diagrams) {
    try { await draw(window.mermaid, item); } catch (e) { console.error(e); }
  }
});
