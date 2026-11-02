// 渲染页里给用户看的文案。译文在 Localizable.xcstrings 里，MarkdownRenderer 按系统语言取好后
// 渲染前放到 window.vvStrings；{xxx} 换成 vars 里的同名值。
export function t(key, vars = {}) {
  const s = window.vvStrings?.[key] ?? key;
  return s.replace(/\{(\w+)\}/g, (m, k) => (k in vars ? String(vars[k]) : m));
}
