/* Development-only syntax check. No package or generated code enters the panel. */
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
let acorn;
try {
  acorn = require('acorn');
} catch (error) {
  // Node includes Acorn for its own tooling. Prefer a regular installation when available.
  const source = process.binding('natives')['internal/deps/acorn/acorn/dist/acorn'];
  if (!source) throw new Error('Install the development parser acorn, then run this check again.');
  const parser = new Module('glass-rooms-es5-parser');
  parser._compile(source, 'bundled-acorn.cjs');
  acorn = parser.exports;
}
function checkSource(source, filename) {
  const tree = acorn.parse(source, { ecmaVersion: 5, locations: true });
  // Acorn accepts block-level declarations as an extension even with ecmaVersion:5.
  // Safari 9 strict mode rejects them before executing ANY statement in the file.
  function visit(node, parent, grandparent) {
    if (node.type === 'FunctionDeclaration') {
      const topLevel = parent && parent.type === 'Program';
      const functionBody = parent && parent.type === 'BlockStatement' && grandparent &&
        /^(FunctionDeclaration|FunctionExpression)$/.test(grandparent.type) && grandparent.body === parent;
      if (!topLevel && !functionBody) {
        throw new Error((filename || 'script') + ':' + node.loc.start.line + ': Safari 9 rejects block-level function declarations. Use a function expression.');
      }
    }
    for (const key of Object.keys(node)) {
      const child = node[key];
      if (Array.isArray(child)) {
        for (const entry of child) if (entry && typeof entry.type === 'string') visit(entry, node, parent);
      } else if (child && typeof child.type === 'string') visit(child, node, parent);
    }
  }
  visit(tree, null, null);
  for (const banned of [/\bfetch\s*\(/, /\bPromise\b/, /\bWebSocket\b/, /\bserviceWorker\b/, /\b(?:Map|Set|WeakMap)\s*\(/, /\b(?:Object|Array)\.from\b/]) {
    if (banned.test(source)) throw new Error('Unsupported runtime construct: ' + banned);
  }
}
module.exports = { checkSource };
if (require.main === module) {
  const directory = path.join(__dirname, '..', 'glass_rooms', 'www');
  for (const filename of fs.readdirSync(directory).filter(name => name.endsWith('.js'))) {
    checkSource(fs.readFileSync(path.join(directory, filename), 'utf8'), filename);
    console.log('PASS: ' + filename + ' ES5 syntax and Safari 9 declaration constraints.');
  }
  console.log('This does not certify Safari 9 or the physical iPad.');
}
