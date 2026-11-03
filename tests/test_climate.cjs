const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../glass_rooms/www/app.js'), 'utf8');
const startup = source.lastIndexOf('  try {\n    init();');
assert.ok(startup > 0);
const testSource = source.slice(0, startup) +
  '  window.test={setState:function(next){state=next;},renderClimate:renderClimate,climateReading:climateReading};\n}());';

function element(tag) {
  return {
    tagName: tag, className: '', textContent: '', children: [], attributes: {},
    appendChild(child) { this.children.push(child); return child; },
    setAttribute(name, value) { this.attributes[name] = value; },
    addEventListener() {}
  };
}
const window = {};
vm.runInNewContext(testSource, {
  window,
  document: {createElement: element, importNode: node => node},
  DOMParser: class { parseFromString() { return {documentElement: element('svg')}; } }
});

function sensor(id, room, deviceClass, state, status = 'ok', unit = '') {
  return {entity_id: id, name: id, domain: 'sensor', category: 'climate', room,
    state, status, attributes: {device_class: deviceClass, unit_of_measurement: unit}};
}
const temperature = sensor('sensor.living_temperature', 'menjador', 'temperature', '21.4', 'ok', '°C');
const humidity = sensor('sensor.living_humidity', 'menjador', 'humidity', '48', 'ok', '%');
const kitchen = sensor('sensor.kitchen_temperature', 'cuina', 'temperature', 'unavailable', 'unavailable', '°C');
const unassigned = sensor('sensor.extra_humidity', null, 'humidity', 'bad', 'ok', '%');
window.test.setState({connected: true, entities: [temperature, humidity, kitchen, unassigned]});
const parent = element('div');
window.test.renderClimate(parent);
const cards = parent.children[1].children;
assert.deepEqual(cards.map(card => card.children[0].textContent),
  ['Menjador', 'Cuina', 'Sense habitació assignada']);
assert.equal(cards[0].children[1].children[2].textContent, '21.4 °C');
assert.equal(cards[0].children[2].children[2].textContent, '48 %');
assert.equal(cards[1].children[1].children[2].textContent, '—');
assert.equal(cards[2].children[1].children[2].textContent, '—');
assert.equal(cards[2].children[1].children[4].textContent, 'Lectura no vàlida');
window.test.setState({connected: false, entities: [temperature]});
assert.equal(window.test.climateReading(temperature), '—');
console.log('PASS: climate readings, grouping and unavailable states.');
