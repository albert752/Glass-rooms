const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const html = fs.readFileSync(path.join(__dirname, '../glass_rooms/www/index.html'), 'utf8');
assert.equal((html.match(/data-pin="[0-9]"/g) || []).length, 10);
assert.ok(html.includes('data-pin="clear"') && html.includes('data-pin="back"'));
assert.ok(!html.includes('id="panel-password"'));

const source = fs.readFileSync(path.join(__dirname, '../glass_rooms/www/app.js'), 'utf8');
const startup = source.lastIndexOf('  try {\n    init();');
assert.ok(startup > 0);
const testSource = source.slice(0, startup) +
  '  window.test={changePin:changePin,updatePinDisplay:updatePinDisplay,submitLogin:submitLogin,setRequest:function(next){request=next;}};\n}());';
const buttons = Array.from({length: 12}, () => ({disabled: false}));
const elements = {
  pinpad: {querySelectorAll: () => buttons},
  'pin-display': {textContent: ''},
  'pin-status': {textContent: ''},
  'login-submit': {disabled: false},
  'login-error': {textContent: ''}
};
const window = {};
vm.runInNewContext(testSource, {window, document: {getElementById: id => elements[id]}});
window.test.updatePinDisplay();
assert.equal(elements['login-submit'].disabled, true);
for(const digit of '123456') { window.test.changePin(digit); }
assert.equal(elements['login-submit'].disabled, false);
assert.ok(!elements['pin-display'].textContent.includes('123456'));
window.test.changePin('back');
assert.equal(elements['login-submit'].disabled, true);
window.test.changePin('6');
window.test.changePin('7');
window.test.changePin('8');
window.test.changePin('9');
assert.equal(elements['pin-status'].textContent, '8 de 6 a 8 dígits introduïts');
let sent;
window.test.setRequest((method, route, body, callback) => {
  sent = {method, route, body};
  callback('PIN incorrecte.', {}, 401);
});
window.test.submitLogin({preventDefault() {}});
assert.equal(sent.route, './api/login');
assert.equal(sent.body.pin, '12345678');
assert.equal(elements['login-error'].textContent, 'PIN incorrecte.');
assert.equal(elements['login-submit'].disabled, true);
assert.equal(elements['pin-status'].textContent, '0 de 6 a 8 dígits introduïts');
window.test.changePin('clear');
console.log('PASS: HTML PIN pad, masking, length limits and login payload.');
