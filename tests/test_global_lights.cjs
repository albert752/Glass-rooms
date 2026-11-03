const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../glass_rooms/www/app.js'), 'utf8');
const startup = source.lastIndexOf('  try {\n    init();');
assert.ok(startup > 0);
const testSource = source.slice(0, startup) +
  '  window.test={setState:function(next){state=next;},setRequest:function(next){request=next;},resetRefresh:function(){authenticated=true;loading=false;pendingUpdate=false;pendingForce=false;},setRenderView:function(next){renderView=next;},refresh:refresh,renderGlobalLights:renderGlobalLights,renderRooms:renderRooms,summaryValue:summaryValue};\n}());';

function element(tag) {
  return {
    tagName: tag, children: [], attributes: {}, listeners: {}, textContent: '', disabled: false,
    appendChild(child) { this.children.push(child); return child; },
    setAttribute(name, value) { this.attributes[name] = value; },
    addEventListener(name, listener) { this.listeners[name] = listener; }
  };
}
const window = {};
const toast = element('div');
const lastUpdate = element('div');
vm.runInNewContext(testSource, {
  window,
  document: {createElement: element, createTextNode: text => ({textContent: text}), importNode: node => node,
    getElementById: id => id === 'toast' ? toast : lastUpdate, hidden: true},
  setTimeout: () => 1, clearTimeout: () => {},
  DOMParser: class { parseFromString() { return {documentElement: element('svg')}; } }
});

function light(id, state, enabled = true, status = 'ok') {
  return {entity_id: id, domain: 'light', category: 'lights', room: null, state, status,
    controls: [{action: 'turn_on', enabled}, {action: 'turn_off', enabled}]};
}
function render(entities, connected = true) {
  window.test.setState({entities, connected, preview: false});
  const parent = element('div');
  window.test.renderGlobalLights(parent);
  return parent.children[0];
}

let control = render([light('light.kitchen', 'off'), light('light.unassigned', 'off')]);
assert.equal(control.disabled, false);
assert.equal(control.children[1].children[0].textContent, 'Encén tots els llums');
assert.equal(control.children[1].children[1].textContent, '2 online · 0 offline');
control = render([light('light.kitchen', 'on'), light('light.unassigned', 'off')]);
assert.equal(control.disabled, false);
assert.equal(control.children[1].children[0].textContent, 'Apaga tots els llums');
const sent = [];
window.test.setRequest((method, path, body, callback) => {
  if(method === 'POST') { sent.push({path, body}); callback(null, {ok: true}, 200); }
});
control.listeners.click();
assert.equal(sent.length, 1);
assert.equal(sent[0].path, './api/lights');
assert.equal(sent[0].body.entity_ids.join(','), 'light.kitchen');
assert.equal(sent[0].body.action, 'turn_off');
assert.equal(toast.className, 'toast hidden');
const alreadyOff = light('light.unassigned', 'off');
alreadyOff.controls[1].enabled = false;
assert.equal(render([light('light.kitchen', 'on'), alreadyOff]).disabled, false);
const partial = render([light('light.kitchen', 'on'), light('light.living', 'on')]);
const attempted = [];
window.test.setRequest((method, path, body, callback) => {
  if(method !== 'POST') { return; }
  attempted.push(body.entity_ids.join(','));
  callback(null, {ok: false, error: 'Primera llum no disponible.'}, 200);
});
partial.listeners.click();
assert.deepEqual(attempted, ['light.kitchen,light.living']);
assert.equal(toast.textContent, 'Primera llum no disponible.');
assert.equal(render([light('light.kitchen', 'off', false)]).disabled, true);
assert.equal(render([light('light.kitchen', 'off', true, 'unavailable')]).disabled, true);
assert.equal(render([light('light.kitchen', 'off')], false).disabled, true);
assert.equal(render([]).disabled, true);

const living = light('light.living', 'on'); living.room = 'menjador';
const missing = light('light.missing', null, false, 'unavailable'); missing.room = 'menjador';
window.test.setState({entities: [living, missing], connected: true, preview: false});
const rooms = element('div');
window.test.renderRooms(rooms);
const firstCard = rooms.children[1].children[0].children[0];
assert.equal(firstCard.children[2].children[1].textContent, '1 online · 1 offline');
assert.equal(window.test.summaryValue('lights'), '1 online · 1 offline');
window.test.setState({entities: [living, missing], connected: false, preview: false});
assert.equal(window.test.summaryValue('lights'), '0 online · 2 offline');
window.test.resetRefresh();
let renders = 0;
window.test.setRenderView(() => { renders++; });
const pendingReads = [];
window.test.setRequest((method, path, body, callback) => {
  if(path === './api/state') { pendingReads.push(callback); }
});
window.test.refresh(false);
window.test.refresh(true);
pendingReads.shift()(null, {entities: [living, missing], connected: false, preview: false}, 200);
assert.equal(pendingReads.length, 1);
pendingReads.shift()(null, {entities: [living, missing], connected: false, preview: false}, 200);
assert.equal(renders, 1);
console.log('PASS: light counts and global control verification gates.');
