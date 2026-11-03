/* Independent classic ES5 bootstrap. No credentials, storage, eval or network. */
(function () {
  var status = document.getElementById('boot-status');
  var stage = 'G1 · boot.js executat; esperant app.js';
  var finished = false;
  var timer;
  function show(message) {
    if (!status) { return; }
    status.hidden = false;
    status.textContent = 'Glass Rooms 1.0.12 · ' + message;
  }
  function fail(message) {
    if (finished) { return; }
    clearTimeout(timer);
    show(stage + ' · ' + message + '. Obre diagnostics.html i comunica el codi que hi apareix.');
  }
  window.GlassRoomsBoot = {
    mark: function (value) { stage = value; show(stage); },
    fail: fail,
    done: function () { finished = true; clearTimeout(timer); if (status) { status.hidden = true; } }
  };
  window.addEventListener('error', function (event) {
    if (finished) { return; }
    var target = event.target || event.srcElement;
    if (target && target.tagName === 'SCRIPT') { fail('B1 · script bloquejat o no descarregat'); return; }
    // Report only the error category and source line, never application data.
    var name = event.error && event.error.name;
    if (!name) { name = /SyntaxError|syntax/i.test(event.message || '') ? 'SyntaxError' : 'Error JavaScript'; }
    fail('B2 · ' + name + (event.lineno ? ' · línia ' + event.lineno : ''));
  }, true);
  show(stage);
  timer = setTimeout(function () { fail('B3 · no s’ha completat l’arrencada'); }, 10000);
}());
