const assert = require('node:assert/strict');
const { checkSource } = require('../scripts/check-es5.cjs');
// Reproduce the class of parse failure previously missed by Acorn's ES5 setting.
assert.throws(() => checkSource('(function(){"use strict"; if(true){function updateLabel(){}}}());'), /block-level/);
assert.throws(() => checkSource('"use strict"; try { function bad(){} } catch(e) {}'), /block-level/);
assert.doesNotThrow(() => checkSource('(function(){"use strict"; function good(){} if(true){var updateLabel=function(){};}}());'));
assert.throws(() => checkSource('const x = () => 1;'));
console.log('PASS: 4 JavaScript compatibility regression cases.');
