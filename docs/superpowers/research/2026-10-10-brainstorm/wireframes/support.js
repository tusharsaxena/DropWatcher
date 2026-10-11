// Offline renderer for the wireframe sources (*.dc.html).
//
// The canvas at https://claude.ai/artifact/66FgCdy9d5txRSBkcLKrNw renders these files with its own
// runtime. This shim implements the small subset they use: {{dotted.path}} holes in text and attributes,
// <sc-for list as>, <sc-if value>, <helmet> hoisting, and a Component class whose renderVals() supplies
// the data. It lets each file be opened directly in a browser and screenshotted to PNG.
(function () {
  window.DCLogic = class { constructor(props) { this.props = props || {}; this.state = {}; } setState(s) { Object.assign(this.state, s); } };

  function lookup(scope, raw) {
    const path = raw.replace(/[{}]/g, '').trim();
    if (path === 'true') return true;
    if (path === 'false') return false;
    if (/^-?\d+(\.\d+)?$/.test(path)) return Number(path);
    return path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), scope);
  }

  function interp(str, scope) {
    return str.replace(/\{\{([^}]+)\}\}/g, (m, p) => { const v = lookup(scope, p); return v == null ? '' : String(v); });
  }

  function unwrap(el) {
    const frag = document.createDocumentFragment();
    while (el.firstChild) frag.appendChild(el.firstChild);
    el.replaceWith(frag);
  }

  function render(node, scope) {
    for (const child of Array.from(node.childNodes)) {
      if (child.nodeType === 3) { if (child.textContent.includes('{{')) child.textContent = interp(child.textContent, scope); continue; }
      if (child.nodeType !== 1) continue;
      const tag = child.tagName.toLowerCase();
      if (tag === 'sc-for') {
        const list = lookup(scope, child.getAttribute('list')) || [];
        const as = child.getAttribute('as');
        const frag = document.createDocumentFragment();
        list.forEach((item, i) => {
          const s = Object.create(scope); s[as] = item; s.$index = i;
          const c = child.cloneNode(true);
          render(c, s);
          while (c.firstChild) frag.appendChild(c.firstChild);
        });
        child.replaceWith(frag);
        continue;
      }
      if (tag === 'sc-if') {
        if (lookup(scope, child.getAttribute('value'))) { render(child, scope); unwrap(child); } else child.remove();
        continue;
      }
      for (const a of Array.from(child.attributes)) if (a.value.includes('{{')) child.setAttribute(a.name, interp(a.value, scope));
      render(child, scope);
    }
  }

  document.addEventListener('DOMContentLoaded', () => {
    const root = document.querySelector('x-dc');
    const script = document.querySelector('script[data-dc-script]');
    const Component = new Function('DCLogic', script.textContent + '\nreturn Component;')(window.DCLogic);
    const vals = new Component({}).renderVals() || {};
    const helmet = root.querySelector('helmet');
    if (helmet) { Array.from(helmet.children).forEach((c) => document.head.appendChild(c)); helmet.remove(); }
    render(root, vals);
    document.body.style.margin = '0';
    document.documentElement.setAttribute('data-rendered', '1');
  });
})();
