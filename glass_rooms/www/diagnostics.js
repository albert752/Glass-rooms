/* Intentionally independent of app.js and its initialization. */
(function () {
  var list = document.getElementById('diagnostic-results');
  function row(text) {
    var item = document.createElement('li');
    item.appendChild(document.createTextNode(text));
    list.appendChild(item);
    return item;
  }
  document.getElementById('diagnostic-js').textContent = 'D1 · JavaScript clàssic executat.';
  row('Versió del diagnòstic: 1.1.9');
  row('Navegador: ' + navigator.userAgent);
  row('D2 · CSS: ' + (window.getComputedStyle && window.getComputedStyle(document.getElementById('css-probe'), null).width === '9px' ? 'aplicat' : 'no aplicat'));
  row('D3 · API: XHR=' + !!window.XMLHttpRequest + ', JSON=' + !!window.JSON + ', DOMParser=' + !!window.DOMParser);
  row('Transport: ' + window.location.protocol + ' · ' + (window.navigator.standalone ? 'pantalla d’inici' : 'navegador'));
  var image = document.getElementById('diagnostic-image');
  var imageRow = row('D4 · SVG: comprovant');
  var inspectImage = function () { imageRow.textContent = 'D4 · SVG: ' + (image.naturalWidth > 0 ? 'carregat' : 'no carregat'); };
  image.onload = inspectImage;
  image.onerror = inspectImage;
  if (image.complete) { inspectImage(); }
  function inspect(path, label) {
    var item = row(label + ': comprovant'), xhr = new XMLHttpRequest();
    xhr.open('GET', path, true);
    xhr.timeout = 10000;
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== 4) { return; }
      item.textContent = label + ': HTTP ' + xhr.status + ' · ' + (xhr.getResponseHeader('Content-Type') || 'sense tipus MIME');
    };
    xhr.ontimeout = function () { item.textContent = label + ': temps esgotat'; };
    xhr.onerror = function () { item.textContent = label + ': error de xarxa o bloqueig del navegador'; };
    xhr.send(null);
  }
  inspect('./app.js?v=1.1.9', 'D5 · descàrrega app.js (no execució)');
  inspect('./style.css?v=1.1.9', 'D6 · descàrrega CSS');
  inspect('./api/session', 'D7 · resposta del servidor');
}());
