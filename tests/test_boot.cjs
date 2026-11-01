const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../glass_rooms/www/boot.js'), 'utf8');
function boot() {
  const status = {hidden: false, textContent: ''};
  let callback, timer, cancelled = false;
  const window = {addEventListener(name, handler) { assert.equal(name, 'error'); callback = handler; }};
  vm.runInNewContext(source, {
    window, document: {getElementById() { return status; }},
    setTimeout(handler) { timer = handler; return 1; }, clearTimeout() { cancelled = true; }
  });
  return {status, api: window.GlassRoomsBoot, error: event => callback(event), timeout: () => timer(), cancelled: () => cancelled};
}
let b = boot();
assert.match(b.status.textContent, /G1/);
b.error({target: {tagName: 'SCRIPT'}});
assert.match(b.status.textContent, /B1/);
assert.equal(b.cancelled(), true);
b = boot();
b.error({message: 'SyntaxError: invalid syntax', lineno: 211});
assert.match(b.status.textContent, /B2.*SyntaxError.*211/);
b = boot();
b.api.mark('G3'); b.api.fail('TypeError');
assert.match(b.status.textContent, /G3.*TypeError/);
b = boot(); b.timeout();
assert.match(b.status.textContent, /B3/);
b = boot(); b.api.done(); b.error({message: 'private application value'});
assert.equal(b.status.hidden, true);
assert.equal(b.cancelled(), true);
assert.doesNotMatch(b.status.textContent, /private application value/);
console.log('PASS: 5 independent bootstrap failure/success scenarios.');
