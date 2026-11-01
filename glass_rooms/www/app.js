/* Glass Rooms: ES5, XHR, no framework or client-side Home Assistant credentials. */
(function () {
  'use strict';
  if(window.GlassRoomsBoot) { window.GlassRoomsBoot.mark('G2 · app.js interpretat'); }
  var ROOMS = [
    {id:'menjador',name:'Menjador'}, {id:'cuina',name:'Cuina'},
    {id:'habitacio',name:'Habitació'}, {id:'despatx',name:'Despatx'},
    {id:'rebedor',name:'Rebedor'}, {id:'bany',name:'Bany'},
    {id:'passadis',name:'Passadís'}, {id:'lavabo',name:'Lavabo'}
  ];
  var ICONS = {
    home:'<path d="M3 10l9-7 9 7v10H3z"/><path d="M9 20v-7h6v7"/>',
    overview:'<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
    light:'<path d="M8 16c0-3-3-4-3-7a7 7 0 0114 0c0 3-3 4-3 7zM9 19h6M10 22h4"/>',
    lightOn:'<path d="M8 16c0-3-3-4-3-7a7 7 0 0114 0c0 3-3 4-3 7v1H8zM9 19h6v1H9zM10 21h4v1h-4z"/>',
    shield:'<path d="M12 3l8 3v6c0 5-8 9-8 9s-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
    spark:'<path d="M12 3l2.4 6.6L21 12l-6.6 2.4L12 21l-2.4-6.6L3 12l6.6-2.4zM20 2v4M18 4h4"/>',
    settings:'<circle cx="12" cy="12" r="3"/><path d="M9 3h6l1 3 3 1 2 5-2 5-3 1-1 3H9l-1-3-3-1-2-5 2-5 3-1z"/>',
    sun:'<circle cx="12" cy="12" r="4"/><path d="M12 1v2M12 21v2M1 12h2M21 12h2M4 4l2 2M18 18l2 2M4 20l2-2M18 6l2-2"/>',
    moon:'<path d="M20 15A9 9 0 019 3a9 9 0 1011 12z"/>',
    refresh:'<path d="M20 8a8 8 0 10.1 8M20 3v5h-5"/>',
    close:'<path d="M6 6l12 12M6 18L18 6"/>',
    water:'<path d="M12 2s-7 8-7 13a7 7 0 0014 0c0-5-7-13-7-13zM8 15a4 4 0 004 4"/>',
    fan:'<circle cx="12" cy="12" r="2"/><path d="M11 10C5 4 12-2 15 4c1 2-1 4-2 6M14 12c8-2 10 7 3 7-3 0-4-3-4-5M10 13c-2 8-10 5-7 0 1-3 4-2 7-2"/>',
    media:'<path d="M9 18V5l11-2v13M9 9l11-2"/><ellipse cx="6" cy="18" rx="3" ry="2"/><ellipse cx="17" cy="16" rx="3" ry="2"/>'
  };
  var state = {connected:false,preview:false,entities:[],fetched_at:null};
  var currentView = 'rooms', csrf = '', authenticated = false, loading = false, busy = false;
  var pollTimer = null, toastTimer = null, modal = null, previousFocus = null, theme = 'auto', glass = false;
  var updateXhr = null, updateRetryTimer = null, updateRevision = 0, updateGeneration = 0, pendingUpdate = false;
  var POLL_INTERVAL = 30000;
  var suppressRoomClickUntil = 0;
  var $ = function (id) { return document.getElementById(id); };
  function el(tag, cls, text) { var n=document.createElement(tag); if(cls) { n.className=cls; } if(text!==undefined) { n.textContent=text; } return n; }
  function empty(n) { while(n.firstChild) { n.removeChild(n.firstChild); } }
  function on(n, type, fn) { n.addEventListener(type,fn,false); }
  function icon(name) {
    var n=el('span','icon'); n.setAttribute('aria-hidden','true');
    // Parse SVG as XML, not HTML: keep the namespace explicit on older WebKit.
    var solid=name==='lightOn';
    var source='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="23" height="23" fill="'+(solid?'currentColor':'none')+'" stroke="'+(solid?'none':'currentColor')+'" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'+(ICONS[name]||ICONS.home)+'</svg>';
    var parsed=new DOMParser().parseFromString(source,'image/svg+xml');
    n.appendChild(document.importNode(parsed.documentElement,true));
    return n;
  }
  function button(text, cls, fn) { var n=el('button',cls,text); n.type='button'; if(fn) { on(n,'click',fn); } return n; }
  function safeNumber(value) { return typeof value==='number' && isFinite(value); }
  function pad(n) { return n<10?'0'+n:String(n); }
  function storePreference() { try { window.localStorage.setItem('glass-rooms-appearance',JSON.stringify({theme:theme,glass:glass})); } catch(ignore) {} }
  function applyTheme() {
    var hour=new Date().getHours(), dark=theme==='night'||(theme==='auto'&&(hour<7||hour>=20));
    document.body.className=(dark?'night':'day')+(glass?' glass':'');
    empty($('time-icon')); $('time-icon').appendChild(icon(dark?'moon':'sun'));
  }
  function clockTick() {
    var d=new Date(), days=['Diumenge','Dilluns','Dimarts','Dimecres','Dijous','Divendres','Dissabte'];
    var months=['gener','febrer','març','abril','maig','juny','juliol','agost','setembre','octubre','novembre','desembre'];
    $('clock').textContent=pad(d.getHours())+':'+pad(d.getMinutes());
    $('date').textContent=days[d.getDay()]+', '+d.getDate()+' de '+months[d.getMonth()];
    applyTheme();
  }
  function toast(message) { clearTimeout(toastTimer); $('toast').textContent=message; $('toast').className='toast'; toastTimer=setTimeout(function() { $('toast').className='toast hidden'; },6000); }
  function request(method,path,body,callback,timeout) {
    var xhr=new XMLHttpRequest(), done=false;
    function finish(error,data,status) { if(done) { return; } done=true; callback(error,data,status); }
    xhr.open(method,path,true); xhr.timeout=timeout||15000;
    if(method==='POST') { xhr.setRequestHeader('Content-Type','application/json'); if(csrf) { xhr.setRequestHeader('X-CSRF-Token',csrf); } }
    xhr.onreadystatechange=function() {
      if(xhr.readyState!==4) { return; }
      var data;
      try { data=JSON.parse(xhr.responseText); } catch(ignore) { data={error:'No s’ha pogut llegir la resposta del servidor.'}; }
      finish(xhr.status>=200&&xhr.status<300?null:(data.error||'No hi ha connexió amb el servidor.'),data,xhr.status);
    };
    xhr.onerror=function() { finish('No hi ha connexió amb el servidor.',null,0); };
    xhr.ontimeout=function() { finish('El servidor no ha respost a temps.',null,0); };
    xhr.send(body?JSON.stringify(body):null);
    return xhr;
  }
  function byCategory(category) { var result=[],i; for(i=0;i<state.entities.length;i++) { if(state.entities[i].category===category) { result.push(state.entities[i]); } } return result; }
  function byRoom(room) { var result=[],i; for(i=0;i<state.entities.length;i++) { if(state.entities[i].room===room) { result.push(state.entities[i]); } } return result; }
  function stateText(entity) {
    if((!state.connected&&!state.demo) || !entity || entity.status==='pending') { return 'Pendent de connexió'; }
    if(entity.status==='missing') { return 'No trobada a Home Assistant'; }
    if(entity.status==='unavailable') { return 'No disponible'; }
    if(entity.status==='unknown' || entity.state===null) { return 'Estat desconegut'; }
    var names={on:'Encès',off:'Apagat',disarmed:'Desarmada',armed_home:'Armada · a casa',armed_away:'Armada · fora',armed_night:'Armada · nit',armed_vacation:'Armada · vacances',arming:'Armant-se',disarming:'Desarmant-se',pending:'Pendent',triggered:'Alarma activada',playing:'En reproducció',paused:'En pausa',idle:'En espera',standby:'En espera'};
    if(entity.domain==='binary_sensor'&&(entity.state==='on'||entity.state==='off')) {
      var dc=(entity.attributes||{}).device_class;
      if(dc==='door'||dc==='window'||dc==='opening') { return entity.state==='on'?'Obert':'Tancat'; }
      if(dc==='motion'||dc==='occupancy'||dc==='presence') { return entity.state==='on'?'Detecció':'Sense detecció'; }
      if(dc==='heat') { return entity.state==='on'?'Escalfant':'Sense escalfar'; }
      return entity.state==='on'?'Actiu':'Inactiu';
    }
    if(entity.domain==='scene') { return 'Estat HA: '+entity.state; }
    if(entity.domain==='sensor') { return entity.state+((entity.attributes||{}).unit_of_measurement?' '+entity.attributes.unit_of_measurement:''); }
    return names[entity.state]||entity.state;
  }
  function setHeading(eyebrow,title,subtitle) { $('eyebrow').textContent=eyebrow; $('page-title').textContent=title; $('page-subtitle').textContent=subtitle; }
  function renderStatus() {
    if(state.demo) { $('last-update').textContent='Simulació de llums · cap ordre real'; return; }
    var d=state.fetched_at?new Date(state.fetched_at):null;
    $('last-update').textContent=state.connected&&d&&!isNaN(d.getTime())?'Actualitzat a les '+pad(d.getHours())+':'+pad(d.getMinutes())+':'+pad(d.getSeconds()):'Esperant dades de casa';
  }
  function renderRooms(parent) {
    var label=el('h2','section-label','LES HABITACIONS'); label.appendChild(el('span','', '8 espais · llisca avall per al resum')); parent.appendChild(label);
    var grid=el('div','room-grid');
    ROOMS.forEach(function(room) {
      var wrap=el('div','room-wrap'), card=button('','room-card',function() { if(Date.now()>=suppressRoomClickUntil) { openRoom(room.id); } });
      card.appendChild(el('h3','room-title',room.name));
      var art=el('img','room-art'); art.src='./assets/'+room.id+'.svg'; art.alt=''; art.setAttribute('aria-hidden','true'); card.appendChild(art);
      var entities=byRoom(room.id), known=0, issues=0, lights=0, unavailableLights=0, lit=false, roomLights=[], canToggle=true, toggleAction, i;
      for(i=0;i<entities.length;i++) {
        if(entities[i].status==='ok') { known++; } else { issues++; }
        if(entities[i].domain==='light') {
          lights++;
          roomLights.push(entities[i]);
          if(entities[i].status==='unavailable') { unavailableLights++; }
          if(entities[i].status==='ok'&&entities[i].state==='on') { lit=true; }
        }
      }
      card.setAttribute('aria-label','Obre '+room.name+(lights?(lit?', amb llums encesos':', llums apagats')+(unavailableLights?', '+unavailableLights+' '+(unavailableLights===1?'llum no disponible':'llums no disponibles'):''):''));
      if(lights) {
        card.className+=' '+(lit?'room-lit':'room-dark');
        toggleAction=lit?'turn_off':'turn_on';
        for(i=0;i<roomLights.length;i++) {
          var roomControls=roomLights[i].controls||[], toggleReady=false, ci;
          if(roomLights[i].status!=='ok') { canToggle=false; }
          for(ci=0;ci<roomControls.length;ci++) { if(roomControls[ci].action===toggleAction&&roomControls[ci].enabled) { toggleReady=true; } }
          if(!toggleReady) { canToggle=false; }
        }
        var badge=button('','room-light-badge',function(event) { if(event) { event.stopPropagation(); } turnRoomLights(room.name,roomLights,toggleAction); });
        badge.className+=' '+(lit?'bulb-lit':'bulb-dark');
        badge.disabled=!canToggle||!state.connected||state.preview||busy;
        badge.setAttribute('aria-label',(lit?'Apaga':'Encén')+' totes les llums de '+room.name);
        badge.setAttribute('title',badge.disabled?'Control pendent de connexió o verificació':(lit?'Apaga':'Encén')+' totes les llums de '+room.name);
        badge.appendChild(icon(lit?'lightOn':'light'));
      }
      var msg=entities.length?((state.connected||state.demo)?known+' amb estat'+(unavailableLights?' · '+unavailableLights+' '+(unavailableLights===1?'llum no disponible':'llums no disponibles'):'')+(issues>unavailableLights?' · '+(issues-unavailableLights)+' pendents':''):'Sense connexió'):'Ubicació pendent';
      var meta=el('div','room-meta'+(issues?' has-issue':'')); meta.appendChild(el('span','status-dot')); meta.appendChild(document.createTextNode(msg)); card.appendChild(meta);
      wrap.appendChild(card); if(lights) { wrap.appendChild(badge); } grid.appendChild(wrap);
    }); parent.appendChild(grid);
  }
  function summaryValue(category) {
    if(!state.connected&&!state.demo) { return '—'; }
    var items=byCategory(category), valid=0,i; for(i=0;i<items.length;i++) { if(items[i].status==='ok') { valid++; } }
    return valid+' / '+items.length+' amb estat';
  }
  function renderOverview(parent) {
    var label=el('h2','section-label','D’UN COP D’ULL'); label.appendChild(el('span','', state.demo?'Llums simulats':'Només lectures reals')); parent.appendChild(label);
    var grid=el('div','summary-grid');
    [{id:'lights',name:'Il·luminació',icon:'light',note:'Llums configurats'}, {id:'security',name:'Seguretat',icon:'shield',note:'Entitats de seguretat configurades'}, {id:'water',name:'Aigua calenta',icon:'water',note:'Entitats d’aigua configurades'}, {id:'media',name:'Música i televisió',icon:'media',note:'Reproductors configurats'}, {id:'fans',name:'Ventiladors',icon:'fan',note:'Ventiladors configurats'}, {id:'switches',name:'Interruptors',icon:'light',note:'Interruptors configurats'}, {id:'scenes',name:'Escenes',icon:'spark',note:'Escenes configurades'}, {id:'other',name:'Altres dispositius',icon:'overview',note:'Altres entitats configurades'}].forEach(function(item) {
      if(!byCategory(item.id).length) { return; }
      var wrap=el('div','summary-wrap'), card=button('','summary-card',function() { openCategory(item.id,item.name); });
      card.appendChild(icon(item.icon)); card.appendChild(el('h3','',item.name)); card.appendChild(el('span','summary-value',summaryValue(item.id))); card.appendChild(el('span','summary-note',item.note)); wrap.appendChild(card); grid.appendChild(wrap);
    }); parent.appendChild(grid);
    parent.appendChild(button('Veure tots els dispositius','outline-button',function() { openCategory('all','Tots els dispositius'); }));
  }
  function renderView() {
    var view=$('view'); empty(view); var buttons=document.querySelectorAll('[data-nav]'),i;
    for(i=0;i<buttons.length;i++) { var active=buttons[i].getAttribute('data-nav')===currentView; buttons[i].className='nav-button'+(active?' active':''); buttons[i].setAttribute('aria-current',active?'page':'false'); }
    if(currentView==='rooms') { setHeading('EL TEU ESPAI','Casa, amb calma.',state.demo?'Previsualització · llums simulats':'Cada estança, al teu ritme.'); renderRooms(view); }
    else { setHeading('LA CASA, D’UN COP D’ULL','Tot al seu lloc.',state.demo?'Previsualització · llums simulats':'L’estat de casa, sense presses.'); renderOverview(view); }
    renderStatus();
  }
  function navigate(to) {
    closeModal();
    if(to==='lights') { openCategory('lights','Il·luminació'); return; }
    if(to==='security') { openCategory('security','Seguretat'); return; }
    if(to==='scenes') { openCategory('scenes','Escenes i ambient'); return; }
    currentView=to; renderView(); window.scrollTo(0,0);
  }
  function openModal(title,eyebrow,type,id) {
    var changed=!modal||modal.type!==type||modal.id!==id;
    if(!modal) { previousFocus=document.activeElement; }
    modal={type:type,id:id}; $('modal-title').textContent=title; $('modal-eyebrow').textContent=eyebrow;
    $('drawer').className='drawer'+(type==='room'?' room-modal':'');
    empty($('modal-content')); $('modal-layer').className='modal-layer'; document.body.style.overflow='hidden';
    if(changed) { $('modal-content').scrollTop=0; $('drawer').focus(); }
    return $('modal-content');
  }
  function closeModal() {
    if(!modal) { return; } var pin=$('alarm-code'); if(pin) { pin.value=''; }
    modal=null; $('modal-layer').className='modal-layer hidden'; $('drawer').className='drawer'; empty($('modal-content')); document.body.style.overflow='';
    if(previousFocus&&document.documentElement.contains(previousFocus)) { previousFocus.focus(); } previousFocus=null;
  }
  function openRoom(id) {
    var room,i; for(i=0;i<ROOMS.length;i++) { if(ROOMS[i].id===id) { room=ROOMS[i]; } }
    if(!room) { return; }
    var parent=openModal(room.name,'LES HABITACIONS','room',id), art=el('img','drawer-art'); art.src='./assets/'+id+'.svg'; art.alt='Il·lustració conceptual de l’estança'; parent.appendChild(art);
    var entities=byRoom(id);
    if(entities.length) { renderEntities(parent,entities); }
    else { var box=el('div','empty-state'); box.appendChild(el('h3','','Un espai per definir.')); box.appendChild(el('p','','Encara no s’ha confirmat quins dispositius hi ha en aquesta estança. Els pots consultar al resum general mentre completes la ubicació.')); box.appendChild(button('Veure dispositius','outline-button',function() { openCategory('all','Tots els dispositius'); })); parent.appendChild(box); }
  }
  function openCategory(category,title) {
    var parent=openModal(title,'A CASA','category',category), items=category==='all'?state.entities:byCategory(category);
    if(!items.length) { parent.appendChild(el('p','empty-state','Pendent de carregar l’inventari. Comprova la connexió amb el panell.')); }
    renderEntities(parent,items);
  }
  function displayAttributes(parent,entity) {
    var a=entity.attributes||{}, parts=[];
    if(entity.status!=='ok'||(!state.connected&&!state.demo)) { return; }
    if(entity.domain==='water_heater') {
      if(safeNumber(a.current_temperature)) { parts.push('Temperatura actual: '+a.current_temperature+' '+(a.temperature_unit||'°')); }
      if(a.operation_mode) { parts.push('Mode: '+a.operation_mode); }
    }
    if(entity.domain==='light') { if(safeNumber(a.brightness)) { parts.push('Brillantor: '+Math.round(a.brightness/255*100)+'%'); } if(safeNumber(a.color_temp_kelvin)) { parts.push('Color: '+a.color_temp_kelvin+' K'); } }
    if(entity.domain==='fan'&&safeNumber(a.percentage)) { parts.push('Velocitat: '+a.percentage+'%'); }
    if(entity.domain==='media_player') { if(a.media_title) { parts.push(a.media_title); } if(safeNumber(a.volume_level)) { parts.push('Volum: '+Math.round(a.volume_level*100)+'%'); } }
    if(parts.length) { parent.appendChild(el('p','device-note',parts.join(' · '))); }
  }
  function renderEntities(parent,entities) {
    var list=el('ul','device-list');
    entities.forEach(function(entity) {
      var item=el('li','device-item'), name=el('h3','device-name',entity.name);
      if(entity.is_group) { name.appendChild(el('span','group-badge','Grup')); } item.appendChild(name);
      item.appendChild(el('p','device-state'+(entity.status==='ok'&&(state.connected||state.demo)?'':' issue'),stateText(entity)));
      displayAttributes(item,entity);
      if(entity.note) { item.appendChild(el('p','device-note',entity.note)); }
      if(entity.inventory_area&&!entity.room) { item.appendChild(el('p','device-note','Àrea de l’inventari: '+entity.inventory_area+' · ubicació física pendent')); }
      var controls=entity.controls||[];
      if(controls.length) { var group=el('div','controls'); controls.forEach(function(control) { renderControl(group,entity,control); }); item.appendChild(group); }
      else if(entity.domain!=='sensor'&&entity.domain!=='binary_sensor') { item.appendChild(el('p','device-note','Controls pendents de verificar.')); }
      item.appendChild(el('small','entity-id',entity.entity_id)); list.appendChild(item);
    }); parent.appendChild(list);
  }
  function renderControl(parent,entity,control) {
    var enabled=control.enabled&&state.connected&&!state.preview&&!busy;
    function act(value) { if(control.kind==='alarm'||control.action.indexOf('alarm_')===0) { alarmPrompt(entity,control); } else { sendAction(entity,control,value); } }
    if(control.kind==='range') {
      var wrap=el('div','range-control'), label=el('label','control-label'), input=el('input'), row=el('div','range-row');
      input.type='range'; input.min=control.min; input.max=control.max; input.step=control.step||1; input.value=safeNumber(control.value)?control.value:control.min; input.disabled=!enabled;
      input.id='range-'+entity.entity_id.replace(/\./g,'-')+'-'+control.action; label.htmlFor=input.id;
      var hasValue=safeNumber(control.value), touched=false;
      var updateLabel=function() { label.textContent=control.label+': '+(hasValue||touched?input.value:'tria un valor')+(control.action==='color_temp_kelvin'&&(hasValue||touched)?' K':''); };
      var apply=button('Aplica','action-button',function() { var value=Number(input.value); act(control.action==='set_percentage'?Math.round(value):value); }); apply.disabled=!enabled||!hasValue;
      var changeRange=function() { touched=true; updateLabel(); apply.disabled=!enabled; };
      updateLabel(); on(input,'input',changeRange); on(input,'change',changeRange);
      wrap.appendChild(label); row.appendChild(input); row.appendChild(apply); wrap.appendChild(row); parent.appendChild(wrap);
    } else if(control.kind==='select') {
      var box=el('div'), select=el('select'), lbl=el('label','control-label',control.label);
      select.id='select-'+entity.entity_id.replace(/\./g,'-')+'-'+control.action; lbl.htmlFor=select.id;
      (control.options||[]).forEach(function(value) { var option=el('option','',value); option.value=value; select.appendChild(option); });
      if(control.value!==undefined&&control.value!==null) { select.value=control.value; } select.disabled=!enabled;
      var submit=button('Aplica el mode','action-button',function() { act(select.value); }); submit.disabled=!enabled; box.appendChild(lbl); box.appendChild(select); box.appendChild(submit); parent.appendChild(box);
    } else { var b=button(control.label,'action-button',function() { act(); }); b.disabled=!enabled; parent.appendChild(b); }
    if(!enabled&&control.reason) { parent.appendChild(el('p','device-note',control.reason)); }
  }
  function alarmPrompt(entity,control) {
    var parent=openModal(control.label,'SEGURETAT','alarm',entity.entity_id), form=el('form');
    parent.appendChild(el('p','info-box','Estat actual: '+stateText(entity)+'. Confirma l’ordre abans d’enviar-la.'));
    if(control.requires_code) {
      var label=el('label','control-label','PIN de l’alarma'), input=el('input'); label.htmlFor='alarm-code'; input.id='alarm-code'; input.type='password'; input.autocomplete='off'; input.setAttribute('autocapitalize','off'); input.setAttribute('spellcheck','false'); input.required=true;
      form.appendChild(label); form.appendChild(input); form.appendChild(el('p','muted','El PIN només s’envia amb aquesta ordre i s’esborra del camp immediatament.'));
    }
    var submit=el('button','primary-button',control.label); submit.type='submit'; form.appendChild(submit);
    on(form,'submit',function(event) { event.preventDefault(); var code=$('alarm-code')?$('alarm-code').value:undefined; if($('alarm-code')) { $('alarm-code').value=''; } sendAction(entity,control,undefined,code); code=null; }); parent.appendChild(form);
  }
  function sendAction(entity,control,value,code) {
    if(busy||!state.connected||state.preview||!control.enabled) { toast('Aquest control encara no està disponible.'); return; }
    busy=true; var payload={entity_id:entity.entity_id,action:control.action}; if(value!==undefined) { payload.value=value; } if(code!==undefined) { payload.code=code; }
    var buttons=$('modal-content').querySelectorAll('button,input,select'),i; for(i=0;i<buttons.length;i++) { buttons[i].disabled=true; }
    request('POST','./api/action',payload,function(error,data,status) {
      busy=false; if(status===401) { requireLogin(); return; }
      if(error) { toast(error); } else { toast((data&&data.message)||'Ordre enviada; pendent de confirmar estat.'); }
      if(modal&&modal.type==='alarm') { openCategory('security','Seguretat'); }
      refresh(true);
    }); payload.code=null; code=null;
  }
  function turnRoomLights(roomName,lights,action) {
    var i;
    if(busy||!state.connected||state.preview||!lights.length) { return; }
    for(i=0;i<lights.length;i++) {
      if(lights[i].status!=='ok') { toast('No es pot canviar l’estat: hi ha un llum no disponible.'); return; }
      var controls=lights[i].controls||[], ready=false, j;
      for(j=0;j<controls.length;j++) { if(controls[j].action===action&&controls[j].enabled) { ready=true; break; } }
      if(!ready) { toast('L’ordre per a aquesta habitació encara no està verificada.'); return; }
    }
    busy=true;
    function finish(error) {
      busy=false;
      if(error) { toast(error); }
      else { toast('Ordre enviada a '+roomName+'; actualitzant l’estat real.'); }
      refresh(true);
    }
    function next(index) {
      if(index>=lights.length) { finish(null); return; }
      request('POST','./api/action',{entity_id:lights[index].entity_id,action:action},function(error,data,status) {
        if(status===401) { busy=false; requireLogin(); return; }
        if(error) { finish(error); return; }
        next(index+1);
      });
    }
    next(0);
  }
  function openSettings() {
    var parent=openModal('Al teu gust.','PREFERÈNCIES','settings','settings'), section=el('div','settings-section');
    section.appendChild(el('h3','','Llum i color')); var segmented=el('div','segmented');
    [{id:'auto',name:'Automàtic'},{id:'day',name:'Dia'},{id:'night',name:'Nit'}].forEach(function(choice) { var b=button(choice.name,theme===choice.id?'selected':'',function() { theme=choice.id; storePreference(); applyTheme(); openSettings(); }); b.setAttribute('aria-pressed',theme===choice.id?'true':'false'); segmented.appendChild(b); });
    section.appendChild(segmented); section.appendChild(el('p','muted','Automàtic: dia de 7 a 20 h, segons el rellotge de l’iPad.')); parent.appendChild(section);
    section=el('div','settings-section'); section.appendChild(el('h3','','Una vista lleugera')); var label=el('label','check-label'), check=el('input'); check.type='checkbox'; check.checked=glass; on(check,'change',function() { glass=check.checked; storePreference(); applyTheme(); }); label.appendChild(check); label.appendChild(document.createTextNode('Activa el contrast suau')); section.appendChild(label); section.appendChild(el('p','muted','Superfícies sense desenfocament, adaptades a Safari d’iOS 9.3.5.')); parent.appendChild(section);
    section=el('div','settings-section'); section.appendChild(el('h3','','Connexió')); section.appendChild(el('p','muted',state.demo?'Previsualització amb llums ficticis. No hi ha connexió amb Home Assistant ni controls actius.':(state.preview?'Previsualització local. No hi ha dades de Home Assistant ni controls actius.':(state.connected?'Home Assistant connectat.':'Pendent de connectar amb Home Assistant.')))); section.appendChild(el('p','muted',state.live_updates?'Canvis d’estat en directe actius.':(state.connected?'Connexió d’esdeveniments reconnectant; comprovació de seguretat cada 30 segons.':'Esperant la connexió d’esdeveniments.'))); section.appendChild(el('p','muted',window.location.protocol==='https:'?'Transport HTTPS.':'Transport HTTP local, sense xifrat.'));
    section.appendChild(button('Comprova la connexió','action-button',function() { refresh(true); })); section.appendChild(button('Informe de verificació','action-button',showAudit));
    if(authenticated&&!state.preview) { section.appendChild(button('Tanca la sessió','action-button',function() { request('POST','./api/logout',{},function(error) { if(error) { toast(error); return; } requireLogin(); }); })); }
    parent.appendChild(section); parent.appendChild(el('p','info-box','Glass Rooms 1.0.11 · Estat en directe via WebSocket de Home Assistant.'));
  }
  function showAudit() {
    var parent=openModal('Verificació','CONNEXIÓ I CAPACITATS','audit','audit'); parent.appendChild(el('p','info-box','Informe de lectura per completar la configuració. No inclou credencials.')); var output=el('pre','audit-json','Carregant…'); parent.appendChild(output);
    request('GET','./api/audit',null,function(error,data) { output.textContent=error||JSON.stringify(data,null,2); });
  }
  function refreshModal() {
    if(!modal||busy) { return; }
    var active=document.activeElement, editing=active&&(active.tagName==='INPUT'||active.tagName==='SELECT');
    if(editing&&state.connected) { return; }
    var scroll=$('modal-content').scrollTop;
    if(modal.type==='category') { var title=$('modal-title').textContent; openCategory(modal.id,title); }
    else if(modal.type==='room') { openRoom(modal.id); }
    else if(modal.type==='alarm'&&!state.connected) { openCategory('security','Seguretat'); }
    $('modal-content').scrollTop=scroll;
  }
  function stopUpdateListener() {
    updateGeneration++; clearTimeout(updateRetryTimer); updateRetryTimer=null;
    if(updateXhr) {
      var xhr=updateXhr; updateXhr=null;
      xhr.onreadystatechange=null; xhr.onerror=null; xhr.ontimeout=null; xhr.abort();
    }
  }
  function listenForUpdates() {
    if(updateXhr||document.hidden||!authenticated||state.preview) { return; }
    var generation=updateGeneration;
    updateXhr=request('GET','./api/updates?since='+updateRevision,null,function(error,data,status) {
      if(generation!==updateGeneration) { return; }
      updateXhr=null;
      if(status===401) { requireLogin(); return; }
      if(error) { updateRetryTimer=setTimeout(listenForUpdates,2000); return; }
      var revision=data&&Number(data.revision);
      if(isFinite(revision)&&revision>updateRevision) { updateRevision=revision; refresh(false); }
      listenForUpdates();
    },30000);
  }
  function schedulePoll() { clearTimeout(pollTimer); if(!document.hidden&&(authenticated||state.preview)) { pollTimer=setTimeout(function() { refresh(false); },POLL_INTERVAL); } }
  function refresh(force) {
    if(loading) { pendingUpdate=true; return; } if(!authenticated&&!state.preview) { session(); return; }
    loading=true;
    request('GET','./api/state',null,function(error,data,status) {
      loading=false;
      if(status===401) { requireLogin(); return; }
      if(error) { state.connected=false; state.error=error; state.fetched_at=null; if(force) { toast(error); } }
      else { state=data; state.entities=state.entities||[]; }
      renderView(); refreshModal(); schedulePoll(); listenForUpdates();
      if(pendingUpdate) { pendingUpdate=false; refresh(false); }
    });
  }
  function requireLogin() {
    authenticated=false; csrf=''; clearTimeout(pollTimer); stopUpdateListener(); updateRevision=0; closeModal(); state={connected:false,preview:false,entities:[],fetched_at:null}; renderView();
    $('login-layer').className='login-layer'; $('panel-password').value='';
    $('login-transport').textContent=window.location.protocol==='https:'?'Connexió HTTPS.':'Aquesta connexió HTTP no xifra la contrasenya. Configura HTTPS abans d’utilitzar credencials reals.';
    $('panel-password').focus();
  }
  function session() {
    if(loading) { return; } loading=true;
    request('GET','./api/session',null,function(error,data) {
      loading=false;
      if(error) { state.error=error+' Comprova que obres el servidor del panell (normalment port 8099).'; state.connected=false; renderView(); clearTimeout(pollTimer); pollTimer=setTimeout(session,12000); return; }
      state.preview=!!data.preview; authenticated=!!data.authenticated; csrf=data.csrf||'';
      if(authenticated||state.preview) { $('login-layer').className='login-layer hidden'; refresh(false); } else { requireLogin(); }
    });
  }
  function installEvents() {
    var nodes=document.querySelectorAll('[data-icon]'),i;
    for(i=0;i<nodes.length;i++) { nodes[i].appendChild(icon(nodes[i].getAttribute('data-icon'))); }
    nodes=document.querySelectorAll('[data-nav]');
    for(i=0;i<nodes.length;i++) { (function(n) { on(n,'click',function() { navigate(n.getAttribute('data-nav')); }); }(nodes[i])); }
    on($('settings-button'),'click',openSettings);
    on($('close-modal'),'click',closeModal); on($('modal-backdrop'),'click',closeModal);
    on($('login-form'),'submit',function(event) {
      event.preventDefault(); var password=$('panel-password').value; $('panel-password').value=''; $('login-submit').disabled=true; $('login-error').textContent='';
      request('POST','./api/login',{password:password},function(error,data) { $('login-submit').disabled=false; if(error) { $('login-error').textContent=error; return; } csrf=data.csrf||''; authenticated=true; $('login-layer').className='login-layer hidden'; refresh(true); }); password=null;
    });
    on(document,'keydown',function(event) {
      if(event.keyCode===27&&modal) { closeModal(); }
      if(event.keyCode!==9) { return; }
      var scope=modal?$('drawer'):($('login-layer').className.indexOf('hidden')===-1?$('login-form'):null); if(!scope) { return; }
      var focusable=scope.querySelectorAll('button:not([disabled]),input:not([disabled]),select:not([disabled]),a[href]'); if(!focusable.length) { return; }
      var first=focusable[0],last=focusable[focusable.length-1];
      if(event.shiftKey&&(document.activeElement===first||document.activeElement===scope)) { event.preventDefault(); last.focus(); }
      else if(!event.shiftKey&&document.activeElement===last) { event.preventDefault(); first.focus(); }
    });
    var start=null;
    on($('main'),'touchstart',function(event) {
      if(currentView!=='rooms'||modal||event.touches.length!==1||window.pageYOffset>0) { start=null; return; }
      var t=event.touches[0];
      start={x:t.clientX,y:t.clientY};
    });
    on($('main'),'touchmove',function(event) {
      if(!start||event.touches.length!==1) { start=null; return; }
      var t=event.touches[0], dx=t.clientX-start.x, dy=t.clientY-start.y;
      if(Math.abs(dx)>=55) { start=null; return; }
      if(dy>20&&event.cancelable!==false) { event.preventDefault(); }
    });
    on($('main'),'touchend',function(event) {
      if(!start) { return; }
      var t=event.changedTouches[0], down=t&&t.clientY-start.y>85&&Math.abs(t.clientX-start.x)<55;
      start=null;
      if(down) { suppressRoomClickUntil=Date.now()+800; navigate('overview'); }
    });
    on($('main'),'touchcancel',function() { start=null; });
    on(document,'visibilitychange',function() { if(document.hidden) { clearTimeout(pollTimer); stopUpdateListener(); if($('alarm-code')) { $('alarm-code').value=''; } } else { clockTick(); refresh(false); listenForUpdates(); } });
    on(window,'pageshow',function(event) { if(event.persisted) { stopUpdateListener(); csrf=''; authenticated=false; updateRevision=0; if($('alarm-code')) { $('alarm-code').value=''; } session(); } });
  }
  function init() {
    try { var pref=JSON.parse(window.localStorage.getItem('glass-rooms-appearance')||'null'); if(pref) { if(pref.theme==='auto'||pref.theme==='day'||pref.theme==='night') { theme=pref.theme; } glass=pref.glass===true; } } catch(ignore) {}
    if(window.GlassRoomsBoot) { window.GlassRoomsBoot.mark('G3 · navegació i icones'); }
    installEvents(); clockTick(); setInterval(clockTick,30000);
    if(window.GlassRoomsBoot) { window.GlassRoomsBoot.mark('G4 · habitacions'); }
    renderView(); session();
  }
  try {
    init();
    var cssReady=window.getComputedStyle && window.getComputedStyle($('css-probe'),null).width==='9px';
    if(cssReady) { if(window.GlassRoomsBoot) { window.GlassRoomsBoot.done(); } else { $('boot-status').hidden=true; } }
    else { if(window.GlassRoomsBoot) { window.GlassRoomsBoot.fail('B4 · CSS no aplicat'); } else { $('boot-status').textContent='Glass Rooms 1.0.11: no s’ha carregat style.css.'; } }
  } catch(startupError) {
    if(window.GlassRoomsBoot) { window.GlassRoomsBoot.fail(startupError.name || 'Error'); return; }
    $('boot-status').hidden=false;
    $('boot-status').textContent='Glass Rooms 1.0.11: no s’ha pogut iniciar la interfície. Torna a carregar la pàgina i comprova que tots els fitxers són de la mateixa versió.';
  }
}());
