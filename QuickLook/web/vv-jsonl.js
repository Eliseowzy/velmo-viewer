(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.VelmoJSONL = api;
  root.velmoRenderJSONL = api.render;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const NUMBER = /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/;
  const LITERAL = /^(?:true|false|null)(?![A-Za-z0-9_])/;

  function escapeHtml(source) {
    return source.replace(/[&<>"]/g, function (character) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[character];
    });
  }

  function token(className, source) {
    return '<span class="' + className + '">' + escapeHtml(source) + "</span>";
  }

  // JSONL 的每一行都是独立 JSON。这里只做词法高亮，不校验或重排记录；
  // 某一行格式错误时，其他行仍然可以正常显示。
  function highlightLine(line) {
    let html = "";
    let plainStart = 0;
    let position = 0;

    function flushPlain(end) {
      if (end > plainStart) html += escapeHtml(line.slice(plainStart, end));
    }

    while (position < line.length) {
      const character = line[position];

      if (character === '"') {
        flushPlain(position);
        let end = position + 1;
        while (end < line.length) {
          if (line[end] === "\\") {
            end += 2;
          } else if (line[end] === '"') {
            end += 1;
            break;
          } else {
            end += 1;
          }
        }
        const className = /^\s*:/.test(line.slice(end)) ? "tok-propertyName" : "tok-string";
        html += token(className, line.slice(position, end));
        position = end;
        plainStart = end;
        continue;
      }

      if (character === "-" || (character >= "0" && character <= "9")) {
        const match = NUMBER.exec(line.slice(position));
        if (match) {
          flushPlain(position);
          html += token("tok-number", match[0]);
          position += match[0].length;
          plainStart = position;
          continue;
        }
      }

      if (character === "t" || character === "f" || character === "n") {
        const match = LITERAL.exec(line.slice(position));
        if (match) {
          flushPlain(position);
          html += token(match[0] === "null" ? "tok-atom" : "tok-bool", match[0]);
          position += match[0].length;
          plainStart = position;
          continue;
        }
      }

      position += 1;
    }

    flushPlain(line.length);
    return html;
  }

  function highlight(source) {
    const normalized = source
      .replace(/^\uFEFF/, "")
      .replace(/\r\n?/g, "\n")
      .replace(/\0/g, "\uFFFD");
    return normalized.split("\n").map(highlightLine).join("\n");
  }

  function render(source, notice) {
    const article = document.querySelector(".velmo-article");
    if (!article) throw new Error("Missing .velmo-article element");
    article.innerHTML = '<pre><code class="language-jsonl">' + highlight(source) + "</code></pre>\n";
    article.classList.add("velmo-code-view");
    if (notice) {
      const element = document.createElement("p");
      element.className = "velmo-preview-notice";
      element.textContent = notice;
      article.prepend(element);
    }
  }

  return { highlight: highlight, render: render };
});
