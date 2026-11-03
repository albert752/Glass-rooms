const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../glass_rooms/www/app.js'), 'utf8');
const startup = source.lastIndexOf('  try {\n    init();');
assert.ok(startup > 0);
const testSource = source.slice(0, startup) +
  '  window.test={setTheme:function(value){theme=value;},applyTheme:applyTheme,toggleTheme:toggleTheme};\n}());';

function element(tag) {
  return {
    tagName: tag, children: [], attributes: {},
    get firstChild() { return this.children[0] || null; },
    appendChild(child) { this.children.push(child); return child; },
    removeChild(child) { this.children.splice(this.children.indexOf(child), 1); },
    setAttribute(name, value) { this.attributes[name] = value; },
    getAttribute(name) { return this.attributes[name]; }
  };
}
const iconButton = element('button');
iconButton.setAttribute('data-icon', 'sun');
const document = {
  body: {className: ''},
  getElementById: () => iconButton,
  createElement: element,
  importNode: node => node
};
const saved = {};
const window = {localStorage: {setItem(key, value) { saved[key] = value; }}};
vm.runInNewContext(testSource, {
  window, document,
  DOMParser: class { parseFromString() { return {documentElement: element('svg')}; } }
});

window.test.setTheme('day');
window.test.applyTheme();
assert.equal(document.body.className, 'day');
assert.equal(iconButton.getAttribute('aria-pressed'), 'false');
window.test.toggleTheme();
assert.equal(document.body.className, 'night');
assert.equal(iconButton.getAttribute('data-icon'), 'moon');
assert.equal(iconButton.getAttribute('aria-pressed'), 'true');
assert.equal(JSON.parse(saved['glass-rooms-appearance']).theme, 'night');
window.test.applyTheme();
assert.equal(document.body.className, 'night');
window.test.toggleTheme();
assert.equal(document.body.className, 'day');
assert.equal(iconButton.getAttribute('data-icon'), 'sun');
assert.equal(JSON.parse(saved['glass-rooms-appearance']).theme, 'day');

const html = fs.readFileSync(path.join(__dirname, '../glass_rooms/www/index.html'), 'utf8');
assert.match(html, /<button[^>]+id="time-icon"[^>]+aria-pressed=/);
console.log('PASS: sun and moon toggle a persistent, accessible theme.');
