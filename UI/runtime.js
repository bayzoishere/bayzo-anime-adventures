'use strict';
const $ = s => document.querySelector(s);
const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const icons = () => lucide.createIcons();
const MODE_ORDER = ['Story','Infinite','Legend Stages','Raids','Infinity Mansion','Dungeons','Portals','Events'];
let dungeonShopScrollTop = 0;
let state = null, view = 'main', editorPage = 1, query = '', filter = 'All', settingsTab = 'General';
let indexDirty = false, settingsDirty = false, modeDirty = false, toastTimer, editTimer, serial = 0;
let indexSaving = null;
let indexMoveBusy = false;
let configResetBusy = false, resetConfigPath = '';
let categoryCopyBusy = false, categoryCopyPreview = null;
let modeSaving = null, settingsSaving = null;
let savedSelection = null, pendingModeAction = null;
let selectedModeRow = 0;
let pendingCardSelection = null, cardSelectionPromise = null;
let pendingNavigation = null, navigationPromise = null;
let modeRevision = 0, settingsRevision = 0, indexRevision = 0;
let feedback = '', feedbackError = false, prioritySortable;
let dungeonSortables = [];
let dungeonSettingsView = 'run', dungeonShopPage = 0;
let recorderDraftName = '', recorderFile = '';
let exportedConfigCode = '', configShareBusy = false;
let exportCatalog = null, exportCatalogLoading = false, exportConfigQuery = '', exportConfigMode = '*';
const selectedExportConfigs = new Set();
const keybindMessages = new Map();
const keybindDrafts = new Map(), pendingKeybindSaves = new Map();
function keybindStatus(key,text,error=false){
  keybindMessages.set(key,{text,error});
  const status=document.querySelector(`[data-keybind-status="${key}"]`);
  if(status){status.textContent=text;status.classList.toggle('error',error);}
}
function keybindField(label,key){
  const message=keybindMessages.get(key)||{text:'',error:false};
  return field(label,key,keybindDrafts.get(key)??state.preferences[key],'text','setting')
    .replace('<input',`<span class="keybind-control"><input aria-describedby="keybind-status-${key}"`)
    .replace('</label>',`<small id="keybind-status-${key}" data-keybind-status="${key}" role="status" class="${message.error?'error':''}">${esc(message.text)}</small></span></label>`);
}
function saveKeybind(el){
  const key=el.dataset.settingField,value=el.value,previous=[...pendingKeybindSaves.values()];
  keybindDrafts.set(key,value);
  const task=(async()=>{
    await Promise.all(previous);
    try{
      await request('keybinds.check',{key,value});
      keybindStatus(key,'Saving...');
      await request('settings.update',{fields:{[key]:value}});
      await request('keybinds.resolve',{key});
      if(keybindDrafts.get(key)===value){
        keybindDrafts.delete(key);
        if(el.dataset.keybindPrevious===undefined)keybindStatus(key,'Saved');
      }
      updateFeedback();
    }catch(error){keybindStatus(key,error.message||'Could Not Save',true);el.setAttribute('aria-invalid','true');}
  })();
  pendingKeybindSaves.set(key,task);
  task.finally(()=>{if(pendingKeybindSaves.get(key)===task)pendingKeybindSaves.delete(key);});
  return task;
}
const selectedExportRecordings = new Set(), selectedExportThemes = new Set();
let exportRecordings = [], exportThemes = [];
const INDEX_HELP = {
  name:'Set any name for the current index',slot:'Choose which unit slot to place, or have the index perform a left click or right click.',upgrade:'Set your desired upgrade for the unit. Ignored while Auto Upgrade is on',
  priority:'Sets the targeting priority for a unit.',wave:'Sets the wave this index runs on. 0 means no wave wait.',
  wait:'Sets the delay before this index runs. 1000 ms = 1 second.',x:'Set the left/right position inside Roblox, or use Select Coordinates and right click to pick a spot.',y:'Set the up/down position inside Roblox, or use Select Coordinates and right click to pick a spot.',
  autoAbility:'Turns on the unit\'s auto ability when its toggle appears, including during upgrades to MAX.',
  unit:'Choose a unit to set up its special actions.',path:'Choose Blessed or Cursed for Gojo v Sukuna.',dioForm:'Choose Dio\'s Rewrite form at upgrade 3.',
  strongestHistory:'Uses Strongest in History after the unit is MAX and charged.',domainClash:'Uses Domain Clash at the wave and delay you set below.',
  domainWave:'Sets the wave to use Domain Clash. 0 means no wave wait.',domainWait:'Sets the delay after the Domain Clash wave. 1000 ms = 1 second.',
  domainImmediate:'Uses Domain Clash after MAX and Strongest in History, ignoring its wave and delay.',domainAbility:'Choose Malevolent Shrine (top left) or Infinite Void (top right).',
  recording:'Choose a saved recording to play instead of unit actions. None uses normal actions.'
};
const PAGE1_HELP_KEYS = ['name','slot','upgrade','priority','wave','wait','x','y','autoAbility'];
const PAGE1_HELP_TEXT = [
  'Index Name: ' + INDEX_HELP.name,
  'Unit Slot/Action: ' + INDEX_HELP.slot,
  'Upgrade: ' + INDEX_HELP.upgrade,
  'Unit Priority: ' + INDEX_HELP.priority,
  'On Wave: ' + INDEX_HELP.wave,
  'Wait (ms): ' + INDEX_HELP.wait,
  'Recording: ' + INDEX_HELP.recording,
  'Coordinates: Sets where to place or click. Enter X/Y, or use Select Coordinates to pick a spot.',
  'Auto Ability: ' + INDEX_HELP.autoAbility,
  'Index Tools: Move, reset, or copy an index. Copying replaces the destination index.'
].join('\n');
const SETTING_HELP = {
  PrivateServer:'Enter your Roblox private server link.',
  UsePrivateServerLink:"On: Uses the provided private server link to rejoin\n\nOff: Doesn't use private server, joins public instead",
  PublicRejoin:"On: Rejoins a public server when starting the macro, and continues to rejoin when needed\n\nOff: Start the macro in your current session and it won't rejoin, but will continue to rejoin public servers for disconnect recovery, challenges, and mode list",
  WaveRestart:'Rejoins at this wave. 0 turns this off.',
  Webhook:'Enter the webhook URL for the Discord channel you want messages sent to.',
  WebhookEnabled:"On: Sends webhooks\n\nOff: Doesn't send webhooks",
  WebhookPingEnabled:'On: Enable pings with webhooks\n\nOff: Disable pings with webhooks',
  WebhookDiscordId:'Enter your Discord User ID',
  WebhookShowMap:'Includes the current map name in webhook messages.',
  WebhookShowMode:'Includes the current mode or challenge type in webhook messages.',
  WebhookShowSessionTime:'Includes the elapsed macro session time in webhook messages.',
  WebhookShowRecord:'Includes this session\'s wins and losses in webhook messages.',
  WebhookShowChallengeRuns:'Includes completed challenge runs.',
  WebhookShowModeRuns:'Includes completed mode runs.',
  WebhookShowAct:'Includes the selected act and difficulty in webhook messages.',
  WebhookShowNext:'Includes the next half hourly and daily challenge countdowns.',
  WebhookShowCompletion:'Includes the match completion time from the results screen.',
  DiscordChannel:'Enter the Discord channel ID where you will use /macro commands.',
  DiscordUserId:'Enter your Discord User ID',
  DiscordToken:'Paste your bot token here. Keep it private; it is saved encrypted on this PC.',
  DiscordBotEnabled:'Enables /macro commands using your bot token, user ID, and channel ID.',
  PlacementRetryDelay:'Sets the wait between unit placement attempts. 1000 ms = 1 second.',
  PathingDelay:'Sets the wait before walking a route. 1000 ms = 1 second.',
  StageClickDelay:'Sets the wait between stage-selection clicks (minimum 1000 ms). 1000 ms = 1 second.',
  VictoryDelay:'Wait on the results screen before leaving or replaying. 1000 ms = 1 second.',
  WebhookScreenshotDelay:'Wait before taking a victory or loss screenshot. 1500 ms = 1.5 seconds.',
  ChallengeEnabled:'Do a challenge at :00 and :30, then return to your modes.',
  DailyChallengeEnabled:'Runs daily challenge when available and when the reset happens',
  ChallengeForceLeave:'On: Will leave at x:30 or x:00 for your challenge no matter what (in the middle of your match for example)\n\nOff: Will wait to finish your current run first and then rejoin for challenges',
  ChallengeFirstMode:'Challenge: Run enabled challenges before the mode queue.\nFirst Mode: Start the queue first, then handle the next enabled challenge reset.',
  StartKey:'Starts the macro.', PauseKey:'Pauses the macro; press again to resume.', CloseKey:'Closes the macro',
  RestartKey:'Restarts the macro', CaptureKey:'Replace this config\'s map screenshot.',
  ZoomtechKey:'Sets the Roblox camera to a top-down view.', WebhookTestKey:'Sends a test webhook',
  RecordKey:'Start the recording. Press again to stop recording.',
  RecordingTestKey:'Playback the recording. Press again to stop playback.'
};
function help(key, group) {
  if (group === 'index' && PAGE1_HELP_KEYS.includes(key)) return '';
  const description = group === 'setting' ? SETTING_HELP[key] : group === 'index' ? INDEX_HELP[key] : '';
  return description ? `<span class="setting-help" tabindex="0" role="button" aria-label="About this setting" data-help="${esc(description)}"><i data-lucide="circle-help"></i></span>` : '';
}
const surfaceCache = new Map();
const htmlCache = new WeakMap();
function replaceWhenChanged(selector, html) {
  const element = $(selector);
  if (element && htmlCache.get(element) !== html) { element.innerHTML = html; htmlCache.set(element,html); }
}
function textWhenChanged(element, text) {
  text = String(text ?? '');
  if (element && element.textContent !== text) element.textContent = text;
}
const requests = new Map();
let processLogSource=null, processLogVisible=[], processLogQueue=[], processLogTimer=0;
let processLogQuery='', processLogErrorsOnly=false;
function processLogMatchesError(line) {
  return /\b(?:errors?|failed|failure|cannot|could not|missing|invalid|denied|blocked|not found)\b|doesn.t contain a valid config code/i.test(line.slice(10));
}
function filteredProcessLog(lines,query,errorsOnly) {
  const search=query.trim().toLowerCase();
  return lines.filter(line=>(!search||line.toLowerCase().includes(search))&&(!errorsOnly||processLogMatchesError(line))).slice(-40);
}
function renderProcessLog() {
  const logEntries=filteredProcessLog(processLogVisible,processLogQuery,processLogErrorsOnly),signature=JSON.stringify([logEntries,processLogQuery,processLogErrorsOnly]);
  if(surfaceCache.get('log')===signature)return;
  const markup=logEntries.reverse().map((line,i)=>`<p><time>${esc(line.slice(0,8))}</time><span class="log-dot ${i?'dim':''}"></span><span class="message">${esc(line.slice(10))}</span></p>`).join('');
  replaceWhenChanged('#log-lines',markup||((processLogQuery.trim()||processLogErrorsOnly)?'<p class="log-empty">No Matching Log Entries</p>':''));
  surfaceCache.set('log',signature);
}
function advanceProcessLog() {
  processLogTimer=0;
  if(!processLogQueue.length)return;
  processLogVisible.push(processLogQueue.shift());
  processLogVisible=processLogVisible.slice(-200);
  renderProcessLog();
  if(processLogQueue.length)processLogTimer=setTimeout(advanceProcessLog,30);
}
function syncProcessLog(lines) {
  if(processLogSource===null || !lines.length) {
    clearTimeout(processLogTimer);processLogTimer=0;processLogQueue=[];
    processLogSource=[...lines];processLogVisible=[...lines];renderProcessLog();return;
  }
  let overlap=Math.min(processLogSource.length,lines.length);
  while(overlap && !processLogSource.slice(-overlap).every((line,i)=>line===lines[i]))overlap--;
  const added=lines.slice(overlap);
  processLogSource=[...lines];
  if(!added.length)return;
  const importBatch=added.length>1 && added.some(line=>line.slice(10).startsWith('Imported '));
  const urgent=added.some(line=>/failed|error|stopped/i.test(line.slice(10)));
  if((importBatch || processLogQueue.length) && !urgent) {
    processLogQueue.push(...added);
    if(!processLogTimer)advanceProcessLog();
  } else {
    clearTimeout(processLogTimer);processLogTimer=0;
    processLogVisible.push(...processLogQueue,...added);processLogQueue=[];
    processLogVisible=processLogVisible.slice(-200);renderProcessLog();
  }
}
const bridge = window.chrome?.webview;
function request(action, data = {}) {
  if (!bridge) return Promise.reject(new Error('Macro connection unavailable'));
  const id = ++serial;
  return new Promise((resolve, reject) => {
    const transfer=['share.export','share.import'].includes(action);
    const timer = setTimeout(() => { requests.delete(id); reject(new Error(transfer?'Config transfer took too long. Check Process Log before trying again.':'Macro did not respond')); }, action==='theme.background.choose' ? 300000 : transfer ? 120000 : action.startsWith('share.') ? 30000 : 10000);
    requests.set(id, {resolve, reject, timer});
    try {
      bridge.postMessage({id, action, data});
    } catch (error) {
      clearTimeout(timer);
      requests.delete(id);
      reject(error);
    }
  });
}
function toast(message, error = false) {
  feedback = message; feedbackError = error;
  updateFeedback();
  const alert = $('.toast');
  clearTimeout(toastTimer);
  alert.textContent = error ? message : '';
  alert.classList.toggle('error',error);
  if (error) toastTimer = setTimeout(() => alert.classList.remove('error'),6000);
}
function updateFeedback() {
  const message = feedback || (indexDirty || modeDirty || settingsDirty ? 'Unsaved changes' : 'All changes saved');
  for (const el of [$('.settings-feedback')]) if (el) {
    el.textContent = message; el.classList.toggle('error-text',feedbackError); el.setAttribute('role',feedbackError ? 'alert' : 'status');
    el.title = message;
  }
}
function report(error) { toast(error.message || String(error), true); }
function options(values, current) {
  return values.map(v => `<option value="${esc(v)}" ${String(v) === String(current) ? 'selected' : ''}>${esc(v)}</option>`).join('');
}
function field(label, key, value, type = 'number', group = 'index') {
  const compactDelay = group === 'setting' && ['PlacementRetryDelay','PathingDelay','StageClickDelay','VictoryDelay','WebhookScreenshotDelay'].includes(key);
  return `<label${compactDelay ? ' class="compact-delay"' : ''}><span class="field-caption">${esc(label)}${help(key,group)}</span><input data-${group}-field="${key}" type="${type}" value="${esc(value)}" ${type === 'number' ? (group==='mode'&&key==='runs'?'min="1" max="100000" step="1" title="Runs: 1 to 100000"':'min="0" step="1"') : ''}></label>`;
}
function select(label, key, values, value, group = 'index') {
  return `<label><span class="field-caption">${esc(label)}${help(key,group)}</span><select data-${group}-field="${key}">${options(values, value)}</select></label>`;
}
function check(label, key, value, group = 'index', checkboxOnly = false) {
  const input = `<input type="checkbox" aria-label="${esc(label)}" data-${group}-field="${key}" ${Number(value) ? 'checked' : ''}>`;
  const caption = `<span class="field-caption">${esc(label)}${help(key,group)}</span>`;
  const tag = group === 'setting' || checkboxOnly ? 'div' : 'label';
  return `<${tag} class="check-row setting-check">${input + caption}</${tag}>`;
}
function filteredIndexes() { return state.indexes.filter(x => (filter === 'All' || (filter === 'Configured' ? x.configured : !x.configured)) && `${x.number} ${x.name}`.toLowerCase().includes(query.toLowerCase())); }
function indexTiles() {
  const selected=pendingCardSelection?.kind==='index'?pendingCardSelection.index:state.selected;
  const cached=indexTiles.cache;
  const fields=['number','name','configured','recording','slot','upgrade'];
  if(cached&&cached.filter===filter&&cached.query===query&&cached.selected===selected&&
    cached.items.length===state.indexes.length&&state.indexes.every((x,i)=>fields.every(key=>x[key]===cached.items[i][key])))return cached.html;
  const matches = filteredIndexes();
  const html=matches.map(x =>
    `<button class="index ${x.number === selected ? 'active' : ''}" data-index="${x.number}" aria-pressed="${x.number === selected}" title="${esc(x.name || 'Index ' + x.number)}"><strong>${esc(x.name || 'Index ' + x.number)}</strong><span>${x.configured ? x.recording ? 'Recording: ' + esc(x.recording) : x.slot > 6 ? (x.slot === 7 ? 'Left Click' : 'Right Click') : `Unit ${x.slot} <b class="tile-upgrade">${x.autoUpgrade ? 'Auto Upgrade' : 'Upgrade ' + esc(x.upgrade)}</b>` : 'Empty'}</span></button>`).join('') || '<p class="empty">No matching indexes</p>';
  indexTiles.cache={filter,query,selected,html,items:state.indexes.map(x=>Object.fromEntries(fields.map(key=>[key,x[key]])))};
  return html;
}
function renderIndexes() {
  if(state.preferences.Mode==='Events'){ $('#panel').innerHTML='<h1 class="april-fools-title">April Fools</h1><div class="april-fools-requirement" role="note"><span class="april-fools-required-label">REQUIRED</span><strong>Equip Elyssia in Unit Slot 1</strong><p>Elyssia must be equipped in Unit Slot 1 for this macro to work.</p></div><p>This is a built-in feature, no need for indexes or configs</p>'; return; }
  editorPage = 1;
  const existingPicker=$('.index-picker'),existingTabs=$('.index-editor-tabs');
  $('#panel').classList.toggle('index-settings-page',editorPage === 1);
  const editorTop = $('.editor-scroll')?.scrollTop || 0;
  const gridTop = $('.index-grid')?.scrollTop || 0;
  const x = state.indexes[state.selected - 1];
  const pageHelp = editorPage === 1 ? `<span class="setting-help" tabindex="0" role="button" aria-label="About Index Settings" data-help-page="1" data-help="${esc(PAGE1_HELP_TEXT)}"><i data-lucide="circle-help"></i></span>` : '';
  const recordings = state.recorder?.files || [];
  const recordingOptions = [...new Set(['',...recordings,...(x.recording ? [x.recording] : [])])];
  const formShape=JSON.stringify([editorPage,editorPage===2?x.unit:null,editorPage===2&&x.unit==='Dio'?state.dioForms:null]);
  const currentEditor=$('.index-editor');
  if(currentEditor?.dataset.formShape===formShape){
    textWhenChanged(currentEditor.querySelector('.editor-heading h2'),'Index '+x.number);
    if(editorPage===1){
      const recording=currentEditor.querySelector('[data-index-field="recording"]');
      const names=Array.from(recording.options,option=>option.value);
      if(JSON.stringify(names)!==JSON.stringify(recordingOptions))
        recording.replaceChildren(...recordingOptions.map(name=>new Option(name?name.replace(/\.txt$/i,''):'None',name)));
    }
    currentEditor.querySelectorAll('[data-index-field]').forEach(control=>{
      const key=control.dataset.indexField;
      let value=x[key];
      if(control.type==='checkbox'){control.checked=!!Number(value);return;}
      if(key==='slot')value=value===7?'Left Click':value===8?'Right Click':value;
      if((key==='x'||key==='y')&&value<0)value='';
      if(key==='domainAbility')value ||= 'Malevolent Shrine';
      value=String(value??'');
      if(control.value!==value)control.value=value;
    });
    const pick=currentEditor.querySelector('#pick');
    if(pick && pick.dataset.picking!==String(!!state.picking)){
      pick.dataset.picking=String(!!state.picking);
      pick.innerHTML=`<i data-lucide="crosshair"></i>${state.picking?'Cancel Selection':'Select Coordinates'}`;
      icons();
    }
    syncIndexTiles();
    return;
  }
  $('#panel').innerHTML = `<div class="index-picker"><div class="panel-title"><h1>Indexes</h1><button id="import-config" class="primary" title="Import Config from a copied code"><i data-lucide="download"></i>Import Config</button></div>
    <div class="search-row"><input id="search" aria-label="Search Indexes" placeholder="Search Indexes" value="${esc(query)}"><select id="filter" aria-label="Filter indexes">${options(['All','Configured','Empty'], filter)}</select></div>
    <div class="index-grid">${indexTiles()}</div></div><div class="index-editor"><div class="index-editor-header"><div class="editor-heading"><h2>Index ${x.number}</h2><div class="index-heading-tools">${pageHelp}</div></div>

    </div><div class="editor-scroll"><div class="editor">${editorPage === 1 ? `<div class="index-basics"><div class="fields">${field('Index Name','name',x.name,'text').replace('<label>','<label class="wide index-name">')}
      ${select('Unit Slot/Action','slot',[1,2,3,4,5,6,'Left Click','Right Click'],x.slot === 7 ? 'Left Click' : x.slot === 8 ? 'Right Click' : x.slot)}${select('Upgrade','upgrade',[...Array.from({length:11},(_,i)=>String(i)),'MAX'],x.upgrade)}${select('Unit Priority','priority',['First','Strongest','Closest','Last','Farthest','Weakest'],x.priority)}
      </div><div class="fields timing-fields">${field('On Wave','wave',x.wave)}${field('Wait (ms)','wait',x.wait)}<label><span class="field-caption">Recording</span><select data-index-field="recording" aria-label="Recording">${recordingOptions.map(name=>`<option value="${esc(name)}" ${name === (x.recording || '') ? 'selected' : ''}>${esc(name ? name.replace(/\.txt$/i,'') : 'None')}</option>`).join('')}</select></label></div><div class="coords">${field('X','x',x.x < 0 ? '' : x.x)}${field('Y','y',x.y < 0 ? '' : x.y)}<button id="pick"><i data-lucide="crosshair"></i>${state.picking ? 'Cancel Selection' : 'Select Coordinates'}</button></div>
      <div class="index-toggles"><div class="checks index-flags">${check('Auto Ability','autoAbility',x.autoAbility,'index',true)}</div></div></div>` :
      `<section class="index-section"><div class="fields two">${select('Unit','unit',['None'],x.unit)}${x.unit === 'Gojo v Sukuna' ? select('Path','path',['Blessed','Cursed'],x.path) : ''}${x.unit === 'Dio' ? select('Dio Form','dioForm',state.dioForms,x.dioForm) : ''}</div></section>
      ${x.unit === 'Gojo v Sukuna' ? `<section class="index-section"><h3>Strongest In History</h3><div class="checks">${check('Activate Strongest in History Form','strongestHistory',x.strongestHistory)}</div></section><section class="domain-section"><h3>Domain Clash</h3><div class="checks">${check('Use Domain Clash','domainClash',x.domainClash)}${check('Immediate on MAX','domainImmediate',x.domainImmediate)}</div><div class="fields two ability-fields">${field('Domain Clash Wave','domainWave',x.domainWave)}${field('After Wave (ms)','domainWait',x.domainWait)}${select('Domain Clash Ability','domainAbility',['Malevolent Shrine','Infinite Void'],x.domainAbility || 'Malevolent Shrine')}</div></section>` : ''}`}
    </div></div></div>`;
  if(existingPicker){
    $('.index-picker').replaceWith(existingPicker);
    syncIndexTiles();
  }
  if(existingTabs){
    $('.index-editor-tabs').replaceWith(existingTabs);
    existingTabs.querySelectorAll('[data-editor-page]').forEach(button=>button.classList.toggle('active',Number(button.dataset.editorPage)===editorPage));
  }
  $('.index-grid').scrollTop = gridTop;
  $('.editor-scroll').scrollTop = editorTop;
  $('.index-editor').dataset.formShape=formShape;
  if($('#pick'))$('#pick').dataset.picking=String(!!state.picking);
  icons();
}
function challengeDuration(value, includeHours = true) {
  if (!/^\d+:\d{2}(?::\d{2})?$/.test(String(value))) return value || 'Off';
  const parts = String(value).split(':').map(Number);
  const [hours,minutes,seconds] = parts.length === 3 ? parts : [0,...parts];
  const units = includeHours ? [[hours,'hour'],[minutes,'minute'],[seconds,'second']] : [[hours * 60 + minutes,'minute'],[seconds,'second']];
  return units.map(([amount,unit])=>`${amount} ${unit}${amount === 1 ? '' : 's'}`).join(', ');
}
function renderRecorder() {
  const r = state.recorder || {files:[],events:[],message:'Ready',name:'',count:0,duration:0};
  if (!r.files.includes(recorderFile)) recorderFile = r.files[0] || '';
  const guide = `Press ${state.preferences.RecordKey || 'F8'} to start recording. Perform your actions inside Roblox, then press the same key to stop. Enter a name and click Save Recording. To test, choose a saved recording and click Load Recording, then press ${state.preferences.RecordingTestKey || 'F10'}. Press that key again to stop testing. Saved files are in Settings/Recordings.`;
  $('#panel').innerHTML = `<div class="recorder-panel"><div class="panel-title recorder-heading"><h1>Recorder <span class="setting-help" tabindex="0" role="button" aria-label="How to record and test" data-help="${esc(guide)}"><i data-lucide="circle-help"></i></span></h1><span class="recorder-state" id="recorder-state"></span></div>
    <section class="recorder-session"><dl class="recorder-metrics"><div><dt>Duration</dt><dd id="recorder-duration"></dd></div><div><dt>Inputs</dt><dd id="recorder-count"></dd></div></dl>
    <div class="recorder-keybinds"><span title="Press once to start recording, then again to stop"><i data-lucide="circle-dot"></i>Start / Stop Recording <kbd>${esc(state.preferences.RecordKey || 'F8')}</kbd></span><span title="Tests the current recording. Press again to stop playback."><i data-lucide="play"></i>Start / Stop Testing <kbd>${esc(state.preferences.RecordingTestKey || 'F10')}</kbd></span></div>
    <p class="recorder-message" id="recorder-message" role="status"></p></section>
    <section class="recorder-save-section"><h2><i data-lucide="file-text"></i>Current Recording</h2><label><span class="field-caption">Recording Name</span><input id="recording-name" type="text" maxlength="80" value="${esc(recorderDraftName || r.name.replace(/\.txt$/i,''))}" placeholder="My Recording" autocomplete="off"></label>
    <div class="recorder-tools"><button id="recording-save" class="primary"><i data-lucide="save"></i>Save Recording</button><button id="recording-discard" title="Discard current draft" aria-label="Discard current draft"><i data-lucide="trash-2"></i></button></div></section>
    <section class="recorder-library"><h2><i data-lucide="folder"></i>Saved Recordings<span id="recorder-file-count" class="recorder-section-count"></span></h2><div class="recorder-library-row"><select id="recorder-file" aria-label="Saved recording">${r.files.length ? options(r.files,recorderFile) : '<option value="">No Saved Recordings</option>'}</select><button id="recording-load" title="Load Recording" aria-label="Load recording"><i data-lucide="folder-open"></i></button><button id="recording-edit" title="Edit Recording" aria-label="Edit recording"><i data-lucide="file-pen-line"></i></button></div></section>
    </div>`;
  $('.recorder-library h2').insertAdjacentHTML('beforeend','<button class="open-folder" data-open-folder="recordings" title="Open Recordings Folder" aria-label="Open Recordings Folder"><i data-lucide="folder-open"></i></button>');
  updateRecorder(); icons();
}
function updateRecorder() {
  if (view !== 'recorder') return;
  const r = state.recorder;
  if (!r) return;
  if (!r.files.includes(recorderFile)) recorderFile = r.files[0] || '';
  $('#recorder-state').textContent = r.recording ? 'Recording' : r.playing ? 'Testing' : r.dirty ? 'Unsaved' : 'Ready';
  $('#recorder-state').classList.toggle('is-recording',!!r.recording);
  $('#recorder-state').classList.toggle('is-playing',!!r.playing);
  $('#recorder-state').classList.toggle('is-draft',!!r.dirty && !r.recording && !r.playing);
  $('#recorder-count').textContent = r.count;
  const seconds = Math.max(0,Math.floor(r.duration / 1000));
  $('#recorder-duration').textContent = `${String(Math.floor(seconds / 60)).padStart(2,'0')}:${String(seconds % 60).padStart(2,'0')}`;
  $('#recorder-file-count').textContent = r.files.length;
  $('#recorder-message').textContent = r.message;
  $('#recording-save').disabled = !!r.recording || !!r.playing || !r.count;
  $('#recording-discard').disabled = !!r.playing || (!r.dirty && !r.count);
  $('#recording-load').disabled = !!r.recording || !!r.playing || !!r.dirty || !r.files.length;
  $('#recording-edit').disabled = !!r.recording || !!r.playing || !r.files.length;
  $('#recording-save').title = r.recording ? 'Stop recording before saving' : r.playing ? 'Stop testing before saving' : !r.count ? 'Record some actions before saving' : 'Save this recording in Settings/Recordings';
  $('#recording-discard').title = r.playing ? 'Stop testing before discarding' : !r.count && !r.dirty ? 'No recording to discard' : 'Delete the current recording draft. Saved files are kept.';
  $('#recording-load').title = r.recording ? 'Stop recording before loading a file' : r.playing ? 'Stop testing before loading a file' : r.dirty ? 'Save or discard the current recording first' : !r.files.length ? 'No saved recordings yet' : 'Load the selected recording for testing';
  $('#recording-edit').title = r.recording || r.playing ? 'Stop recording or testing before editing a file' : !r.files.length ? 'No saved recordings yet' : 'Open the selected recording as an editable text file';
  $('#recording-name').disabled = !!r.recording || !!r.playing;
  $('#recorder-file').disabled = !!r.recording || !!r.playing || !!r.dirty || !r.files.length;
  replaceWhenChanged('#recorder-file',r.files.length ? options(r.files,recorderFile) : '<option value="">No Saved Recordings</option>');
}
function renderMain() {
  const p = state.preferences, stats = state.stats;
  const scrollTop = $('#panel').scrollTop;
  const completed = Number(state.wins) + Number(state.losses);
  const winRate=completed ? Math.round(Number(state.wins)/completed*100) : 0;
  const metric = (label,value,kind = '') => `<div class="overview-metric ${kind}"><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`;
  const timer=(label,key,enabled,daily)=>{
    const raw=enabled ? String(stats[key] || 'Off') : 'Off';
    const parts=/^\d+:\d{2}(?::\d{2})?$/.test(raw) ? raw.split(':').map(Number) : null;
    const [hours,minutes,seconds]=parts ? (parts.length===3 ? parts : [0,...parts]) : [0,0,0];
    const value=parts ? daily ? `${hours}h ${minutes}m ${String(seconds).padStart(2,'0')}s` : `${hours*60+minutes}m ${String(seconds).padStart(2,'0')}s` : raw;
    return `<div class="overview-metric" title="${esc(challengeDuration(raw,daily))}"><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`;
  };
  const mapFacts = [['Gamemode',p.Mode || 'None'],[p.Mode==='Portals'?'Portal Name':'Map',p.Mode==='Portals'?p.PortalName:state.mapName || 'None']];
  if(p.Mode==='Dungeons'&&state.dungeon){mapFacts.push(['Dungeon Depth',state.dungeon.depth?state.dungeon.depth+' / 20':'Detecting'],['Hearts',state.dungeon.hearts>=0?String(state.dungeon.hearts):'Detecting'],['Room Wins / Losses',state.dungeon.roomWins+' / '+state.dungeon.roomLosses]);}
  if (['Story','Legend Stages','Raids'].includes(p.Mode)) mapFacts.push(['Act',p.Act]);
  if (p.Mode === 'Story' || p.Mode === 'Raids') {
    const selectable = p.Mode === 'Story' || state.catalog?.Raids?.find(map=>map.name === state.mapName)?.difficulty;
    mapFacts.push(['Difficulty',selectable ? p.Difficulty : 'Hard']);
  }
  if (p.Mode === 'Boss Rush') {
    mapFacts.push(['Trait Mode',p.BossRushMode]);
    if (state.mapName === 'Makima') mapFacts.push(['Card Modifier',p.MakimaCard]);
  }
  $('#panel').innerHTML = `<div class="main-overview">
    <div class="panel-title overview-heading"><h1>Overview</h1></div>
    <section class="overview-section current-map" aria-labelledby="overview-mode-title"><h2 id="overview-mode-title"><i data-lucide="layers"></i>Current Mode</h2><dl class="overview-map-facts">${mapFacts.map(([label,value])=>metric(label,value)).join('')}</dl></section>
    <section class="overview-section session-results"><h2><i data-lucide="chart-no-axes-combined"></i>Session Results</h2>
      <dl class="overview-results">${metric('Wins',state.wins || 0,'result-win')}${metric('Losses',state.losses || 0,'result-loss')}</dl>
      <dl class="overview-facts">${metric('Win Rate',completed ? winRate+'%' : '--','result-rate')}${metric('Completed Runs',completed)}${metric('Session Time',stats.Elapsed || '00:00:00')}</dl>
    </section>
    <section class="overview-section challenge-overview"><h2><i data-lucide="clock-3"></i>Challenges</h2><dl class="overview-facts">${timer('Next Half Hourly','Half hourly challenge in',Number(p.ChallengeEnabled),false)}${timer('Next Daily','Daily challenge in',Number(p.DailyChallengeEnabled),true)}</dl></section>
    <section class="overview-section main-keybinds"><h2><i data-lucide="keyboard"></i>Keybinds</h2><div class="main-keybind-list">${[['StartKey','F1','Start Macro'],['PauseKey','F2','Pause/Resume Macro'],['CloseKey','F3','Close Macro'],['RestartKey','F4','Restart Macro']].map(([key,fallback,label])=>`<span><kbd>${esc(p[key]||fallback)}</kbd> = ${label}</span>`).join('')}</div></section>
  </div>`;
  icons();
  $('#panel').scrollTop = scrollTop;
}
function modeDraft() {
  const p = state.preferences;
  if(!MODE_ORDER.includes(p.Mode)){
    const queued=state.modes[state.taskIndex-1]||state.modes[0];
    return {portalName:queued?.portalName||'',mode:queued?.mode||'Story',map:queued?.map||'Planet Greenie',act:'Act '+(queued?.act||1),
      runs:queued?.runs||'1',difficulty:queued?.difficulty||'Normal',bossRushMode:p.BossRushMode,makimaCard:p.MakimaCard,contractPriority:p.ContractPriority.split('|')};
  }
  return {portalName:p.PortalName||'',mode:p.Mode, map:p.Map, act:'Act ' + p.Act,
    runs:p.Runs, difficulty:p.Difficulty, bossRushMode:p.BossRushMode, makimaCard:p.MakimaCard, contractPriority:p.ContractPriority.split('|')};
}
let draftMode;
function modeCardSubtitle(mode) {
  if (mode.mode === 'Portals') return 'Portals';
  if (mode.mode === 'Dungeons') return 'Dungeons';
  if (mode.mode === 'Infinity Mansion') return `Infinity Mansion / ${mode.difficulty || 'Normal'}`;
  if (mode.mode === 'Event' || mode.mode === 'Events' || mode.mode === 'Infinite') return mode.mode;
  if (mode.mode === 'Infinity Castle') return mode.bossRushMode;
  const label = mode.mode === 'Legend Stages' ? 'Legend Stage' : mode.mode;
  return `${label} / ${mode.mode === 'Boss Rush' ? mode.bossRushMode : 'Act ' + mode.act}`;
}
function updateModeControls() {
  const add=$('#add-mode'), label=state.taskIndex?'New Mode':'Add Mode';
  add.disabled = !!modeSaving || !!pendingCardSelection;
  if(add.dataset.label!==label){add.dataset.label=label;add.innerHTML=`<i data-lucide="plus"></i>${label}`;icons();}
  $('#delete-mode').disabled = !selectedModeRow;
  document.querySelectorAll('[data-mode-move]').forEach(button => {
    const next = selectedModeRow + Number(button.dataset.modeMove);
    button.disabled = !selectedModeRow || next < 1 || next > state.modes.length;
  });
  updateCardSelectionState();
}
function renderModes(reset = false) {
  const existingList=$('.mode-list');
  const scrollTop = $('#panel').scrollTop;
  const editorTop = $('.mode-editor')?.scrollTop || 0, listTop = $('.mode-list')?.scrollTop || 0;
  prioritySortable?.destroy(); prioritySortable = null;
  if (reset || !draftMode) draftMode = modeDraft();
  const m = draftMode, meta = state.catalog[m.mode]?.find(x => x.name === m.map) || state.catalog[m.mode]?.[0];
  if (!meta) { $('#panel').innerHTML = '<h1>Modes</h1>'; return; }
  m.map = meta.name;
  const acts = Array.from({length:meta.acts}, (_,i)=>'Act ' + (i+1));
  if (!acts.includes(m.act)) m.act = acts[0];
  $('#panel').innerHTML = `<div class="panel-title"><h1>Modes</h1><span class="subtle">${state.modes.length} queued</span></div><div class="mode-editor"><div class="fields two">
    ${select('Gamemode','mode',MODE_ORDER.filter(mode=>state.catalog[mode]?.length),m.mode,'mode')}${m.mode==='Portals'?field('Portal Name','portalName',m.portalName||'','search','mode').replace('<input','<input maxlength="80" placeholder="Enter Portal Name"'):['Infinity Mansion','Infinity Castle','Dungeons'].includes(m.mode)?'':select(['Event','Events'].includes(m.mode) ? 'Event Type' : 'Map','map',state.catalog[m.mode].map(x=>x.name),m.map,'mode')}
    ${['Portals','Infinity Mansion','Dungeons','Infinite','Boss Rush','Event','Events','Infinity Castle'].includes(m.mode) ? '' : select('Act','act',acts,m.act,'mode')}
    ${['Boss Rush','Infinity Castle'].includes(m.mode) ? select('Trait Mode','bossRushMode',['Traits','Traitless'],m.bossRushMode,'mode') : ''}
    ${meta.difficulty && m.act !== 'Infinite' ? select(m.mode==='Infinity Mansion'?'Difficulty Type':'Difficulty','difficulty',['Normal','Hard'],m.difficulty||'Normal','mode') : ''}${field('Runs','runs',m.runs,'number','mode')}
    ${m.mode === 'Boss Rush' && m.map === 'Makima' ? select('Card Modifier','makimaCard',['Unit Slot','Damage','Placement Limit'],m.makimaCard,'mode') : ''}</div>
    </div><section class="mode-queue"><div class="mode-list-heading"><h2>Mode List</h2></div>
    <div class="mode-list">${state.modes.map((m,i)=>`<div class="mode-row ${i + 1 === selectedModeRow ? 'active' : ''}"><span class="subtle">${i + 1}</span><span class="mode-row-details"><strong>${esc(m.mode==='Portals'?m.portalName:m.mode==='Dungeons'?'Dungeons':m.mode==='Infinity Mansion'?'Infinity Mansion':m.mode==='Infinity Castle'?'Infinity Castle':m.map)}</strong><small>${esc(modeCardSubtitle(m))}</small></span><div class="mode-row-tools"><span class="mode-runs subtle">${m.runs} ${Number(m.runs) === 1 ? 'run' : 'runs'}</span><button data-mode="${i + 1}" title="Edit mode ${i + 1}" aria-label="Edit mode ${i + 1}"><i data-lucide="pencil"></i>Edit</button></div></div>`).join('')}</div>
    </section>`;
  if(existingList && existingList.querySelectorAll('.mode-row').length===state.modes.length){
    $('.mode-list').replaceWith(existingList);
    updateModeRows();
  }
  icons();
  $('#panel').scrollTop = scrollTop;
  $('.mode-editor').scrollTop = editorTop; $('.mode-list').scrollTop = listTop;
  updateModeControls();
}
function initPriorityDrag() {
  prioritySortable?.destroy(); prioritySortable = null;
  if ($('#priority-cards')) prioritySortable = Sortable.create($('#priority-cards'), {
    draggable:'.contract-card', animation:matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : 140,
    easing:'cubic-bezier(.2,.8,.2,1)', ghostClass:'contract-placeholder', chosenClass:'contract-chosen', dragClass:'contract-drag',
    forceFallback:true, fallbackOnBody:true, fallbackTolerance:3, swapThreshold:1,
    scroll:true, scrollSensitivity:45, scrollSpeed:12,
    onStart:()=>document.body.classList.add('reordering'),
    onEnd:async event=>{
      document.body.classList.remove('reordering');
      if (event.oldIndex === event.newIndex) return;
      await persistPriorityOrder();
    }
  });
}
function initDungeonPriorityDrag(){
  dungeonSortables.forEach(sortable=>sortable.destroy());dungeonSortables=[];
  document.querySelectorAll('[data-dungeon-list]').forEach(list=>{
    if(list.dataset.dungeonList==='DungeonShopPriority'){
      list.scrollTop=dungeonShopScrollTop;
      list.addEventListener('scroll',()=>{dungeonShopScrollTop=list.scrollTop;},{passive:true});
    }
    dungeonSortables.push(Sortable.create(list,{draggable:'li',handle:'.dungeon-drag-handle',animation:matchMedia('(prefers-reduced-motion: reduce)').matches?0:140,ghostClass:'dungeon-priority-ghost',chosenClass:'dungeon-priority-chosen',forceFallback:true,fallbackOnBody:true,scroll:true,direction:'vertical',fallbackTolerance:4,scrollSensitivity:45,scrollSpeed:8,
      onEnd:async event=>{
        if(list.dataset.dungeonList==='DungeonShopPriority')dungeonShopScrollTop=list.scrollTop;
        if(event.oldIndex===event.newIndex)return;
        const key=list.dataset.dungeonList,order=String(state.preferences[key]).split('|'),visible=[...list.querySelectorAll('li')].map(row=>row.dataset.dungeonName);order.splice(Number(list.dataset.dungeonOffset||0),visible.length,...visible);
        try{await saveSettings();await request('settings.update',{fields:{[key]:order.join('|')}});toast('Priority saved');}
        catch(error){report(error);}finally{renderSettings();}
      }
    }));
  });
}
async function persistPriorityOrder() {
  const order = [...document.querySelectorAll('#priority-cards .contract-card')].map(el=>el.dataset.contractName);
  document.querySelectorAll('#priority-cards .priority-rank').forEach((el,i)=>el.textContent=i+1);
  try { await request('event.priority',{contractPriority:order}); toast('Priority saved'); }
  catch(error) { renderSettings(); report(error); }
}
let discordGuideIndex = 0;
function discordGuideStep() {
  const steps = [
    {title:'Create Your Bot', image:'Discord-Token.png', alt:'Discord Bot page with a red arrow pointing to Reset Token',
      text:'<ol><li>Open the Developer Portal. Choose <strong>New Application</strong>, name it, and click <strong>Create</strong>.</li><li>Open <strong>Bot &gt; Reset Token</strong> and copy your token.</li></ol><button id="discord-open-portal"><i data-lucide="external-link"></i>Open Developer Portal</button><p class="discord-guide-warning">Keep your token private. Never include it in shared settings.</p>'},
    {title:'Invite Your Bot', image:'Discord-Installation.png', alt:'Discord default installation settings showing the bot and applications.commands scopes',
      text:'<ol><li>Open <strong>Installation</strong>, enable <strong>Guild Install</strong>, and choose <strong>Discord Provided Link</strong>.</li><li>Add <strong>bot</strong> and <strong>applications.commands</strong>. Choose <strong>View Channels</strong>, <strong>Send Messages</strong>, and <strong>Attach Files</strong>.</li><li>Open the install link, choose your server, and authorize.</li></ol><p>Leave <strong>Interactions Endpoint URL</strong> blank.</p>'},
    {title:'Copy Your IDs', text:'<ol><li>In Discord, enable <strong>User Settings &gt; Advanced &gt; Developer Mode</strong>.</li><li>Right-click <strong>your own profile</strong> and copy its User ID.</li><li>Right-click your <strong>server text channel</strong> and copy its Channel ID.</li></ol>',
      images:[['Discord-Copy-User-ID.png','Copy User ID in the profile context menu','Your User ID'],['Discord-Copy-Channel-ID.png','Copy Channel ID in the channel context menu','Channel ID']]},
    {title:'Connect And Test', image:'Macro-Connection.png', alt:'Macro integration fields with example IDs and a hidden token',
      text:'<ol><li>Paste your User ID, Channel ID, and Bot Token into the matching fields above.</li><li>Turn on <strong>Enable Discord Integration</strong> and click <strong>Save Settings</strong>.</li><li>Wait for <strong>Discord commands registered: /macro</strong> in the log.</li></ol><p>In your chosen channel, try <code>/macro screenshot</code>. Use <code>/macro pause</code> before <code>/macro modes</code>.</p><p>Keep the macro open and your computer awake.</p>'}
  ];
  const step = steps[discordGuideIndex];
  const imageSizes = {'Discord-Token.png':[1135,385],'Discord-Installation.png':[1362,530],'Discord-Copy-User-ID.png':[574,996],'Discord-Copy-Channel-ID.png':[850,1158],'Macro-Connection.png':[400,357]};
  const figure = (file, alt, caption = '') => `<figure class="discord-guide-image"><div class="discord-guide-media" style="width:${imageSizes[file][0]}px"><img src="GuideImages/${file}" width="${imageSizes[file][0]}" height="${imageSizes[file][1]}" alt="${alt}" loading="lazy">${file === 'Discord-Token.png' ? '<i data-lucide="arrow-down-left" class="discord-token-arrow" aria-hidden="true"></i>' : ''}</div>${caption ? `<figcaption>${caption}</figcaption>` : ''}</figure>`;
  return `<div class="discord-guide-step-heading"><span class="discord-guide-number">${discordGuideIndex+1}</span><h3 tabindex="-1">${step.title}</h3><span class="discord-guide-progress">Step ${discordGuideIndex+1} of 4</span></div>
    ${step.text}${step.images ? `<div class="discord-guide-images">${step.images.map(parts=>figure(...parts)).join('')}</div>` : figure(step.image,step.alt)}
    <div class="discord-guide-navigation"><button data-discord-guide="-1" ${discordGuideIndex === 0 ? 'disabled' : ''}><i data-lucide="chevron-left"></i>Back</button><button ${discordGuideIndex === 3 ? 'id="discord-guide-done"' : 'data-discord-guide="1"'}>${discordGuideIndex === 3 ? 'Done' : 'Next'}<i data-lucide="${discordGuideIndex === 3 ? 'check' : 'chevron-right'}"></i></button></div>`;
}
function discordSetupGuide() {
  return `<details class="discord-setup-guide"><summary><i data-lucide="book-open"></i>Discord Bot Setup Guide</summary><div class="discord-guide-content">${discordGuideStep()}</div></details>`;
}

const themePresets = {
  Default:['#19191b','#222225','#2d2b2e','#151517','#40383d','#f4eef0','#b1a2a8','#f08e9d','#351920','#432d35'],
  Rose:['#19161a','#241e24','#322932','#131115','#51404d','#fff3f7','#c8b5c0','#ff7196','#30121e','#432732'],
  Lavender:['#191720','#242030','#342c43','#131119','#504360','#f5f0ff','#c5bbd7','#bb9dff','#221336','#3b2d50'],
  Mint:['#141c19','#1c2924','#293a33','#101713','#3e5a4e','#effff7','#b7cfbf','#61e6b4','#102f23','#294a3c'],
  Ocean:['#141b22','#1c2934','#293a48','#10161d','#3d596d','#f0f9ff','#b5c9d9','#49bfff','#102c3e','#263e52'],
  Amber:['#1e1915','#29221b','#3a3026','#17130f','#65503b','#fff5e9','#d1ba97','#f5a623','#30200c','#493421'],
  Light:['#f2f4f7','#ffffff','#e6ebf2','#ffffff','#c3ccd8','#202a37','#526174','#1d5bd6','#ffffff','#dae7fc'],
  Graphite:['#1c1e20','#282b2e','#363b40','#141618','#60676e','#f5f6f7','#c0c6cd','#d2d5da','#202428','#3b4249'],
  Cherry:['#1c1215','#291c20','#3c282d','#140c0f','#643c45','#fff2f3','#d5b5bd','#ff6570','#330e14','#4b252e'],
  Blossom:['#fff0f5','#fffafb','#f5dfe8','#ffffff','#d9afc2','#452232','#795062','#bd2869','#ffffff','#f0cedf'],
  Arctic:['#eaf4f9','#f8fdff','#d8eaf2','#ffffff','#adcbd9','#1c3949','#3d5c6e','#087991','#ffffff','#cae5ef'],
  'High Contrast':['#000000','#080808','#191919','#000000','#c8c8c8','#ffffff','#ededed','#ffe14a','#000000','#302b0a'],
};
const themeFields = [['bg','Background'],['surface','Panels'],['raised','Buttons'],['field','Input Boxes'],['line','Borders'],['text','Text'],['muted','Secondary Text'],['accent','Accent'],['accent-ink','Accent Text'],['select','Selection']];
let customThemeOpen=false, customThemeDraft=null, customThemeBase='Default', themeSaving=false, themeSaveError=false;
let savedThemes=null, themesLoading=false, customThemeName=null;
let backgroundEditorOpen=false, backgroundDraft=null, backgroundChoosing=false, backgroundSuspended=false, backgroundRemoving=false;
let customPreviewPage='main';
window.setBackgroundSuspended=value=>{backgroundSuspended=!!value;updateBackgroundMedia();};
const defaultBackground=()=>({file:'',label:'',opacity:35,dim:35,fit:'Fill',paused:false});
function backgroundOptions(value){
  try {
    const data=typeof value==='string'?JSON.parse(value||'{}'):value||{};
    if(data.file && !/^[a-f0-9]{16}\.(png|jpe?g|gif|mp4)$/i.test(data.file))return defaultBackground();
    return {...defaultBackground(),...data,paused:false};
  } catch{return defaultBackground();}
}
function renderBackgroundMedia(host,options,visible){
  if(!host)return;
  const stopped=options.paused;
  const signature=JSON.stringify([options.file,options.fit,stopped,visible]);
  host.style.opacity=Number(options.opacity)/100;
  host.style.setProperty('--media-dim',Number(options.dim)/100);
  host.dataset.fit=options.fit;
  if(host.dataset.mediaSignature===signature)return;
  host.dataset.mediaSignature=signature;
  host.querySelector('video')?.pause();host.replaceChildren();
  host.style.backgroundImage='';
  host.hidden=!options.file || !visible;
  if(host.hidden)return;
  const video=/\.mp4$/i.test(options.file);
  const media=document.createElement(video?'video':'img');
  media.setAttribute('aria-hidden','true');
  if(video){media.muted=true;media.defaultMuted=true;media.loop=true;media.playsInline=true;media.autoplay=!stopped;media.preload='auto';}
  media.addEventListener('error',()=>{
    if(host.dataset.mediaSignature!==signature)return;
    host.hidden=true;
    const message=$('#background-message');
    if(message)message.textContent='Background could not play. Choose a compatible image or H.264 MP4.';
  },{once:true});
  if(video){
    media.addEventListener('loadeddata',()=>{
      if(host.dataset.mediaSignature!==signature)return;
      if(!stopped)media.play().catch(()=>{const message=$('#background-message');if(message)message.textContent='Playback paused. Use Play Animation to retry.';});
    },{once:true});
  } else if(options.fit==='Tile' || (stopped && /\.gif$/i.test(options.file))){
    media.addEventListener('load',()=>{
      if(host.dataset.mediaSignature!==signature)return;
      if(options.fit==='Tile' && !(stopped && /\.gif$/i.test(options.file))){
        host.style.backgroundImage=`url("${media.src}")`;media.remove();media.removeAttribute('src');
      } else {
        const canvas=document.createElement('canvas');
        const scale=Math.min(1,1920/media.naturalWidth,1080/media.naturalHeight);
        canvas.width=options.fit==='Tile'?host.clientWidth:Math.round(media.naturalWidth*scale);
        canvas.height=options.fit==='Tile'?host.clientHeight:Math.round(media.naturalHeight*scale);
        const context=canvas.getContext('2d');
        if(options.fit==='Tile'){context.fillStyle=context.createPattern(media,'repeat');context.fillRect(0,0,canvas.width,canvas.height);}
        else context.drawImage(media,0,0,canvas.width,canvas.height);
        media.replaceWith(canvas);media.removeAttribute('src');
      }
    },{once:true});
  }
  host.append(media);media.src=(video?'https://video.macro.example/':'https://media.macro.example/')+encodeURIComponent(options.file);
}
function updateBackgroundMedia(){
  const background=backgroundOptions(state?.preferences.ThemeBackground);
  const active=!backgroundRemoving && !!background.file;
  document.body.classList.toggle('media-background',active);
  renderBackgroundMedia($('#ui-background'),background,active && !document.hidden && !backgroundSuspended && Number(background.opacity)>0);
  renderBackgroundMedia($('#custom-preview-background'),backgroundDraft||defaultBackground(),view==='themes' && customThemeOpen && !document.hidden && !backgroundSuspended);
}
document.addEventListener('visibilitychange',updateBackgroundMedia);
async function loadSavedThemes() {
  if(themesLoading)return;
  themesLoading=true;
  try {
    const reply=await request('theme.list');savedThemes=reply.result.themes;
    if(view==='themes' && customThemeOpen)renderThemes();
  } catch(error){report(error);}
  finally{themesLoading=false;}
}
async function saveNamedTheme(colors,name,resetting=false) {
  if(themeSaving)return;
  themeSaving=true;themeSaveError=false;updateCustomThemeState();
  try {
    await window.flushEdits();
    const reply=await request('theme.set',{preset:'Custom',name,colors:Object.fromEntries(themeFields.map(([key],i)=>[key,colors[i]])),background:backgroundDraft||backgroundOptions(state.preferences.ThemeBackground)});
    savedThemes=reply.result?.themes || savedThemes;
    customThemeDraft=[...colors];customThemeName=name;
    applyTheme();if(view==='themes' && customThemeOpen)renderThemes();toast(resetting?'Colors reset and saved':'Custom theme saved');
  } catch(error){themeSaveError=true;report(error);}
  finally{themeSaving=false;updateCustomThemeState();}
}
function savedCustomTheme() {
  try {
    const colors=JSON.parse(state?.preferences.CustomTheme || '{}');
    if(themeFields.every(([key])=>/^#[0-9a-f]{6}$/i.test(colors[key])))return themeFields.map(([key])=>colors[key]);
  } catch {}
  return null;
}
function themeLight(color) {
  const rgb=color.match(/[0-9a-f]{2}/gi).map(value=>parseInt(value,16));
  return rgb[0]*0.299+rgb[1]*0.587+rgb[2]*0.114>160;
}
function applyTheme() {
  updateBackgroundMedia();
  const custom=state?.preferences.ThemePreset==='Custom' ? savedCustomTheme() : null;
  const preset = custom ? 'Custom' : themePresets[state?.preferences.ThemePreset] ? state.preferences.ThemePreset : 'Default';
  const colors=custom || themePresets[preset];
  const signature=preset+colors.join('');
  if (document.body.dataset.themeSignature === signature) return;
  document.body.dataset.themeSignature=signature;
  document.body.dataset.preset = preset;
  document.body.dataset.tone = themeLight(colors[0]) ? 'light' : 'dark';
  themeFields.forEach(([key],i)=>document.body.style.setProperty('--'+key,colors[i]));
  document.body.style.setProperty('--red',document.body.dataset.tone === 'light' ? '#b83248' : '#ff9aab');
}
function renderCustomPreviewPage() {
  const body=$('#custom-theme-preview .custom-preview-body');
  if(!body)return;
  const facts='<div><span>Gamemode</span><b>Story</b><span>Map</span><b>Planet Greenie</b><span>Act</span><b>Act 1</b></div>';
  const pages={
    main:`<div class="custom-preview-controls"><div class="custom-preview-game"><span>Roblox</span></div><div class="custom-preview-log"><strong>Process Log</strong><span>12:34:56</span> Ready</div></div><div class="custom-preview-stats"><strong>Overview</strong><h4>Current Mode</h4>${facts}<h4>Session Results</h4><div><span>Wins</span><b class="custom-preview-win">12</b><span>Losses</span><b>3</b><span>Win Rate</span><b>80%</b></div></div>`,
    modes:`<div class="custom-preview-controls"><strong>Mode List</strong><div class="custom-preview-mode selected"><b>Story | Planet Greenie | Act 1</b><span>1 Run</span><button tabindex="-1"><i data-lucide="pencil"></i>Edit</button></div><div class="custom-preview-mode"><b>Story | Walled City | Act 1</b><span>5 Runs</span><button tabindex="-1"><i data-lucide="pencil"></i>Edit</button></div></div><div class="custom-preview-stats"><strong>Mode Actions</strong><div class="custom-preview-fields"><span>Gamemode</span><input value="Story" readonly aria-label="Preview Gamemode"><span>Map</span><input value="Planet Greenie" readonly aria-label="Preview Map"></div><div class="custom-preview-commands"><button tabindex="-1">New Mode</button><button class="theme-preview-accent" tabindex="-1">Save Changes</button></div></div>`,
    settings:`<div class="custom-preview-controls"><strong>Settings</strong><div class="custom-preview-sections"><span class="selected">General</span><span>Webhooks</span><span>Challenges</span><span>Delays</span><span>Keybinds</span></div><h4>Discord Integration</h4><span class="custom-preview-muted">Enable Discord Integration</span></div><div class="custom-preview-stats"><strong>General</strong><div class="custom-preview-fields"><span>Private Server Link</span><input value="" placeholder="Private Server Link" readonly aria-label="Preview Private Server Link"></div><div class="custom-preview-setting"><span class="custom-preview-toggle" aria-hidden="true"></span>Use Private Server Link</div><div class="custom-preview-commands"><button class="theme-preview-accent" tabindex="-1">Save Settings</button></div></div>`
  };
  body.innerHTML=`<nav class="custom-preview-nav" aria-label="Theme Preview">${[['main','layout-dashboard','Main'],['modes','layers','Modes'],['settings','settings-2','Settings']].map(([page,icon,label])=>`<button data-theme-preview-page="${page}" aria-pressed="${page===customPreviewPage}" class="${page===customPreviewPage?'selected':''}"><i data-lucide="${icon}"></i>${label}</button>`).join('')}</nav>${pages[customPreviewPage]}`;
  body.dataset.previewPage=customPreviewPage;
  icons();
}
function renderExport() {
  $('#settings').innerHTML = `<div class="config-export-page"><div class="export-list-heading"><h1>Export Configs</h1></div><section class="share-section"><div class="export-list-heading"><h2>Choose Configs</h2><button id="refresh-export-configs" title="Refresh Configs"><i data-lucide="refresh-cw"></i>Refresh</button></div><div class="export-list-tools"><select id="export-config-mode" aria-label="Config Mode"></select><input id="export-config-search" type="search" aria-label="Search Configs" placeholder="Search Configs" value="${esc(exportConfigQuery)}"><div class="setting-check"><input type="checkbox" id="select-all-export-configs" aria-label="Select All Configs" title="Select all configs across every mode"><span>Select All</span></div></div><div id="export-config-list"></div><div class="share-options"><div class="check-row setting-check"><input type="checkbox" id="export-mode-list" checked aria-label="Add Mode List"><span>Add Mode List</span>${help('modes','export')}</div><div class="check-row setting-check"><input type="checkbox" id="export-safe-settings" checked aria-label="Add Settings"><span>Add Settings</span>${help('settings','export')}</div></div><div class="share-code-actions"><span id="export-config-count" class="subtle"></span><button class="primary" id="generate-config-code"><i data-lucide="package-open"></i>Generate Code</button></div></section><section class="share-section"><h2>Config Code</h2><textarea id="export-config-code" readonly rows="3" spellcheck="false" aria-label="Exported config code">${esc(exportedConfigCode)}</textarea><div class="share-code-actions"><span id="config-code-size" class="subtle">${exportedConfigCode?exportedConfigCode.length+' characters':''}</span><button id="copy-config-code" ${exportedConfigCode?'':'disabled'}><i data-lucide="copy"></i>Copy Code</button></div><p id="config-export-message" role="status"></p></section></div>`;
  renderExportList();
  $('#export-config-code').before($('#config-export-message'));
  $('#export-mode-list').checked=false;
  $('#export-safe-settings').checked=false;
  const codeSection=$('#export-config-code').closest('.share-section');
  const codeHeading=codeSection.querySelector('h2');
  const exportActions=$('#generate-config-code').closest('.share-code-actions');
  exportActions.classList.add('export-generate-actions');
  const optionsHeading=document.createElement('h2');
  optionsHeading.textContent='Export Options';
  codeHeading.before(optionsHeading,$('.share-options'),exportActions);
  icons();
  if(exportCatalog===null && !exportCatalogLoading)loadExportConfigs();
}
function exportGroupMembers(group){
  if(group==='@recordings')return [selectedExportRecordings,exportRecordings];
  if(group==='@themes')return [selectedExportThemes,exportThemes];
  return [selectedExportConfigs,(exportCatalog||[]).filter(config=>config.mode===group).map(config=>config.path)];
}
function renderExportList(rebuild = true) {
  const modes=[...new Set((exportCatalog||[]).map(config=>config.mode))];
  if(!['*','@recordings','@themes',...modes].includes(exportConfigMode))exportConfigMode='*';
  const categories=modes.map(mode=>({value:mode,label:mode,count:exportCatalog.filter(config=>config.mode===mode).length}));
  categories.sort((a,b)=>b.count-a.count);
  categories.push({value:'@recordings',label:'Recordings',count:exportRecordings.length},{value:'@themes',label:'Custom Themes',count:exportThemes.length});
  replaceWhenChanged('#export-config-mode','<option value="*">All Configs</option>'+categories.map(item=>`<option value="${esc(item.value)}">${esc(item.label)} (${item.count})</option>`).join(''));
  $('#export-config-mode').value=exportConfigMode;
  $('#export-config-mode').disabled=exportCatalog===null;
  const recordingView=exportConfigMode==='@recordings',themeView=exportConfigMode==='@themes';
  const searchLabel=recordingView?'Search Recordings':themeView?'Search Themes':'Search Configs';
  $('#export-config-search').placeholder=searchLabel;$('#export-config-search').setAttribute('aria-label',searchLabel);
  const selection=recordingView?selectedExportRecordings:themeView?selectedExportThemes:selectedExportConfigs;
  const names=recordingView?exportRecordings:exportThemes;
  if(rebuild){
  const groupHeading=(title,count,icon,group)=>`<h3><i data-lucide="${icon}"></i>${esc(title)}<input type="checkbox" class="export-group-toggle" data-export-group="${esc(group)}" aria-label="Select all ${esc(title)}" title="Select or clear every file in ${esc(title)}"><span title="${count} files">${count}</span></h3>`;
  const assetGroup=(title,type,names,selected)=>{
    const matches=names.filter(name=>`${title} ${name}`.toLowerCase().includes(exportConfigQuery.toLowerCase()));
    return `<section class="export-mode-group" aria-label="${title}">${groupHeading(title,matches.length,type==='recording'?'video':'palette',type==='recording'?'@recordings':'@themes')}${matches.map(name=>`<div class="export-config-row"><input type="checkbox" data-export-${type}="${esc(name)}" aria-label="Export ${esc(name)}" ${selected.has(name)?'checked':''}><div><strong>${esc(name)}</strong></div></div>`).join('')||`<p class="share-notice">${names.length?'No matching files.':'No saved files.'}</p>`}</section>`;
  };
  if(recordingView||themeView){
    $('#export-config-list').innerHTML=assetGroup(recordingView?'Recordings':'Custom Themes',recordingView?'recording':'theme',names,selection);
  }else{
    const configs=(exportCatalog||[]).filter(config=>(exportConfigMode==='*'||config.mode===exportConfigMode)&&`${config.name} ${config.mode} ${config.path}`.toLowerCase().includes(exportConfigQuery.toLowerCase()));
    const groups=new Map();
    for(const config of configs){if(!groups.has(config.mode))groups.set(config.mode,[]);groups.get(config.mode).push(config);}
    const sections=new Map([...groups].map(([mode,items])=>[mode,`<section class="export-mode-group" aria-label="${esc(mode)} configs">${groupHeading(mode,items.length,'layers',mode)}${items.map(config=>`<div class="export-config-row"><input type="checkbox" data-export-config="${esc(config.path)}" aria-label="Export ${esc(config.name)} ${esc(config.mode)}" ${selectedExportConfigs.has(config.path)?'checked':''}><div><strong>${esc(config.name)}</strong><span>${esc(config.path.split('/').pop())}</span></div></div>`).join('')}</section>`]));
    if(exportConfigMode==='*'){
      sections.set('@recordings',assetGroup('Recordings','recording',exportRecordings,selectedExportRecordings));
      sections.set('@themes',assetGroup('Custom Themes','theme',exportThemes,selectedExportThemes));
    }
    $('#export-config-list').innerHTML=categories.map(category=>sections.get(category.value)||'').join('')||`<p class="share-notice">${exportCatalog===null?'Loading configs...':'No matching configs.'}</p>`;
  }
  icons();
  }else{
    document.querySelectorAll('#export-config-list [data-export-config],#export-config-list [data-export-recording],#export-config-list [data-export-theme]').forEach(input=>{
      const selected=input.dataset.exportConfig?selectedExportConfigs:input.dataset.exportRecording?selectedExportRecordings:selectedExportThemes;
      input.checked=selected.has(input.dataset.exportConfig||input.dataset.exportRecording||input.dataset.exportTheme);
    });
  }
  document.querySelectorAll('[data-export-group]').forEach(toggle=>{
    const [selected,names]=exportGroupMembers(toggle.dataset.exportGroup);
    const count=names.filter(name=>selected.has(name)).length;
    toggle.checked=!!names.length&&count===names.length;
    toggle.indeterminate=count>0&&count<names.length;
    toggle.disabled=!names.length||configShareBusy;
  });
  const total=selectedExportConfigs.size+selectedExportRecordings.size+selectedExportThemes.size;
  $('#export-config-count').textContent=`${total} selected`;
  $('#generate-config-code').disabled=!total||configShareBusy;
  const all=$('#select-all-export-configs');
  const lists=exportConfigMode==='*'?[[selectedExportConfigs,(exportCatalog||[]).map(config=>config.path)],[selectedExportRecordings,exportRecordings],[selectedExportThemes,exportThemes]]:[[selection,recordingView||themeView?names:(exportCatalog||[]).map(config=>config.path)]];
  const available=lists.reduce((sum,[,names])=>sum+names.length,0);
  const count=lists.reduce((sum,[selected,names])=>sum+names.filter(name=>selected.has(name)).length,0);
  all.checked=!!available&&count===available;all.indeterminate=count>0&&!all.checked;
  all.setAttribute('aria-label',recordingView?'Select All Recordings':themeView?'Select All Custom Themes':'Select All Configs');
  all.title=all.getAttribute('aria-label');
}
async function loadExportConfigs() {
  if(exportCatalogLoading)return;
  exportCatalogLoading=true;
  try {
    const reply=await request('share.list');
    exportCatalog=reply.result.configs;
    exportRecordings=reply.result.recordings||[];exportThemes=reply.result.themes||[];
    for(const [selection,names] of [[selectedExportRecordings,exportRecordings],[selectedExportThemes,exportThemes]])
      for(const name of selection)if(!names.includes(name))selection.delete(name);
    const available=new Set(exportCatalog.map(config=>config.path));
    for(const path of selectedExportConfigs)if(!available.has(path))selectedExportConfigs.delete(path);
    if(view==='export')renderExportList();
  } catch(error) {if($('#config-export-message'))$('#config-export-message').textContent=error.message;}
  finally {exportCatalogLoading=false;}
}
function invalidateExportCode() {
  exportedConfigCode='';
  if($('#export-config-code'))$('#export-config-code').value='';
  if($('#copy-config-code'))$('#copy-config-code').disabled=true;
  if($('#config-code-size'))$('#config-code-size').textContent='';
  if($('#config-export-message'))$('#config-export-message').textContent='';
}
function renderThemes() {
  $('#custom-preview-background video')?.pause();
  const selected = state.preferences.ThemePreset || 'Default';
  if(customThemeOpen) {
    if(!customThemeDraft){
      customThemeBase=themePresets[selected]?selected:'Default';
      customThemeDraft=[...(selected==='Custom' ? savedCustomTheme() || themePresets.Default : themePresets[customThemeBase])];
    }
    $('#settings').innerHTML=`<div class="themes-page"><div class="themes-heading"><h1>Themes</h1><div class="theme-editor-tabs"><button id="theme-show-presets"><i data-lucide="layout-grid"></i>Presets</button><button id="theme-show-custom" aria-pressed="true"><i data-lucide="sliders-horizontal"></i>Custom</button></div></div><div class="custom-theme-toolbar"><h2>Custom Theme</h2><div><span>Start From</span><select id="custom-theme-base" aria-label="Starting Preset">${options(Object.keys(themePresets),customThemeBase)}</select><button id="custom-theme-reset" title="Reset Colors To Starting Preset"><i data-lucide="rotate-ccw"></i>Reset Colors</button></div></div><div class="custom-theme-colors">${themeFields.map(([key,label],i)=>`<div class="custom-theme-row"><span>${label}</span><input type="color" data-theme-color="${i}" value="${customThemeDraft[i]}" aria-label="${label} Color">${['R','G','B'].map((channel,j)=>`<label class="theme-rgb">${channel}<input type="number" min="0" max="255" step="1" data-theme-rgb="${i}" data-channel="${j}" value="${parseInt(customThemeDraft[i].slice(1+j*2,3+j*2),16)}" aria-label="${label} ${channel}"></label>`).join('')}</div>`).join('')}</div><div class="custom-theme-preview" id="custom-theme-preview"><strong>Preview</strong><span>Secondary Text</span><input value="Input Box" readonly tabindex="-1"><button tabindex="-1">Button</button><button class="theme-preview-accent" tabindex="-1">Selected</button></div><div class="custom-theme-footer"><span id="custom-theme-message" role="status"></span><button class="primary" id="save-custom-theme"><i data-lucide="save"></i>Save Theme</button></div></div>`;
    const colorRows=[...document.querySelectorAll('.custom-theme-row')];
    customThemeName ??= state.preferences.CustomThemeName || 'Custom Theme';
    backgroundDraft ??= backgroundOptions(state.preferences.ThemeBackground);
    $('.custom-theme-toolbar').insertAdjacentHTML('beforeend',`<div class="custom-design-tabs"><button id="theme-edit-colors" aria-pressed="${!backgroundEditorOpen}"><i data-lucide="palette"></i>Colors</button><button id="theme-edit-background" aria-pressed="${backgroundEditorOpen}"><i data-lucide="image"></i>Background</button></div>`);
    const names=(savedThemes||[]).map(theme=>theme.name);
    $('.custom-theme-toolbar').insertAdjacentHTML('afterend',`<div class="custom-theme-library"><div><span>Saved Themes</span><select id="saved-custom-theme" aria-label="Saved Themes"><option value="">None</option>${options(names,names.includes(customThemeName)?customThemeName:'')}</select></div><div><span>Theme Name</span><input id="custom-theme-name" maxlength="48" value="${esc(customThemeName)}" aria-label="Theme Name"></div></div>`);
    if(savedThemes===null)loadSavedThemes();
    $('.custom-theme-footer').insertAdjacentHTML('afterbegin','<span id="custom-theme-save-status" role="status" aria-live="polite"></span>');
    $('#save-custom-theme').innerHTML='<i data-lucide="save"></i><span>Save Theme</span>';
    $('.custom-theme-library>div:last-child').append($('#save-custom-theme'));
    $('.custom-theme-library>div:first-child').insertAdjacentHTML('beforeend','<button class="open-folder" data-open-folder="themes" title="Open Custom Themes Folder" aria-label="Open Custom Themes Folder"><i data-lucide="folder-open"></i></button>');
    for(const row of colorRows)
      for(const label of row.querySelectorAll('.theme-rgb'))
        label.firstChild.textContent='';
    $('.custom-theme-colors').innerHTML='';
    for(const [title,start] of [['Surfaces & Borders',0],['Text & Accents',5]]) {
      const section=document.createElement('section');
      section.className='custom-theme-group';
      section.innerHTML=`<div class="custom-theme-group-heading"><h3>${title}</h3><span>Color</span><span>R</span><span>G</span><span>B</span></div>`;
      section.append(...colorRows.slice(start,start+5));
      $('.custom-theme-colors').append(section);
    }
    $('#custom-theme-preview').innerHTML='<div id="custom-preview-background" class="ui-background" aria-hidden="true" hidden></div><div class="custom-preview-heading"><strong>Preview</strong><span>Capy&#39;s AA Macro</span></div><div class="custom-preview-body"></div>';
    renderCustomPreviewPage();
    $('.custom-theme-colors').hidden=backgroundEditorOpen;
    $('.themes-page').classList.toggle('background-editor-open',backgroundEditorOpen);
    $('.custom-theme-library').hidden=backgroundEditorOpen;
    $('.custom-theme-toolbar>div:not(.custom-design-tabs)').hidden=backgroundEditorOpen;
    $('.custom-theme-toolbar h2').textContent=backgroundEditorOpen?'Background':'Custom Theme';
    if(backgroundEditorOpen){
      $('.custom-theme-colors').insertAdjacentHTML('afterend',`<section class="custom-background-editor">
        <div class="background-file-tools"><div class="background-file-details"><strong class="background-file-name">None</strong><span>PNG / JPG / GIF / MP4</span></div><button id="background-choose"><i data-lucide="folder-open"></i>Choose File</button><button id="background-remove" ${backgroundDraft.file?'':'disabled'}><i data-lucide="trash-2"></i>Remove</button></div>
        <div class="background-controls">
          <label><span>Opacity <output id="background-opacity-value">${backgroundDraft.opacity}%</output></span><input type="range" min="0" max="100" data-background-field="opacity" value="${backgroundDraft.opacity}"></label>
          <label><span>Darkening <output id="background-dim-value">${backgroundDraft.dim}%</output></span><input type="range" min="0" max="100" data-background-field="dim" value="${backgroundDraft.dim}"></label>
          <label><span>Fit</span><select data-background-field="fit">${options(['Fill','Fit','Tile'],backgroundDraft.fit)}</select></label>
          <div class="background-display-actions"><button id="background-save" class="primary"><i data-lucide="save"></i><span>Save Background</span></button></div>
        </div><p id="background-message" role="status"></p>
      </section>`);
    }
    if(/\.mp4$/i.test(backgroundDraft.file))document.querySelector('[data-background-field="fit"] option[value="Tile"]')?.remove();
    if($('#background-choose')){
      $('#background-choose').title='PNG, JPG, GIF, MP4; up to 20 MB. MP4: 30 seconds, 1080p, 30 FPS.';
      $('.background-file-name').textContent=backgroundDraft.label || backgroundDraft.file || 'None';
    }
    updateCustomThemePreview();icons();return;
  }
  $('#settings').innerHTML = `<div class="themes-page"><div class="themes-heading"><h1>Themes</h1></div><div class="theme-presets">${Object.entries(themePresets).map(([name,colors])=>`<button class="theme-preset" data-preset-choice="${name}" aria-pressed="${name===selected}" style="--preview-bg:${colors[0]};--preview-surface:${colors[1]};--preview-accent:${colors[7]};--preview-ink:${colors[8]};--preview-text:${colors[5]};--preview-line:${colors[4]}"><span class="theme-preview" aria-hidden="true"><span class="theme-preview-bar"><span></span><span></span><span></span></span><span class="theme-preview-body"><span class="theme-preview-rail"><i data-lucide="layout-dashboard"></i><i data-lucide="layers"></i><i data-lucide="settings-2"></i></span><span class="theme-preview-content"><span class="theme-preview-title"></span><span class="theme-preview-line"></span><span class="theme-preview-line short"></span><span class="theme-preview-control"></span></span></span></span><span class="theme-preset-name">${name}<span class="theme-choice-icon"><i data-lucide="${name===selected?'check':'paintbrush'}"></i></span></span></button>`).join('')}</div></div>`;
  $('.themes-heading').insertAdjacentHTML('beforeend','<div class="theme-editor-tabs"><button id="theme-show-presets" aria-pressed="true"><i data-lucide="layout-grid"></i>Presets</button><button id="theme-show-custom"><i data-lucide="sliders-horizontal"></i>Custom</button></div>');
  icons();
}
function updateCustomThemePreview() {
  const preview=$('#custom-theme-preview');
  if(!preview)return;
  themeFields.forEach(([key],i)=>preview.style.setProperty('--'+key,customThemeDraft[i]));
  preview.classList.toggle('has-media',!!backgroundDraft?.file);
  updateBackgroundMedia();
  const luminance=hex=>hex.match(/[0-9a-f]{2}/gi).map(v=>parseInt(v,16)/255).map(v=>v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4).reduce((sum,v,i)=>sum+v*[0.2126,0.7152,0.0722][i],0);
  const contrast=(a,b)=>{const x=luminance(a),y=luminance(b);return (Math.max(x,y)+0.05)/(Math.min(x,y)+0.05);};
  const low=[[5,0],[5,1],[5,2],[5,3],[6,0],[6,1],[8,7]].some(([a,b])=>contrast(customThemeDraft[a],customThemeDraft[b])<4.5);
  $('#custom-theme-message').textContent=low?'Some text colors may be hard to read.':'';
  updateCustomThemeState();
}
function updateCustomThemeState() {
  const status=$('#custom-theme-save-status'),button=$('#save-custom-theme');
  if(!status || !button)return;
  const applied=(state.preferences.ThemePreset==='Custom' && savedCustomTheme()) || themePresets[state.preferences.ThemePreset] || themePresets.Default;
  const dirty=customThemeName!==(state.preferences.CustomThemeName || '') || customThemeDraft.some((color,i)=>color.toLowerCase()!==applied[i].toLowerCase()) || JSON.stringify(backgroundDraft||defaultBackground())!==JSON.stringify(backgroundOptions(state.preferences.ThemeBackground));
  const invalid=!!document.querySelector('.theme-rgb input:invalid') || !/^[a-z0-9][a-z0-9 _-]{0,47}$/i.test(customThemeName) || customThemeName.endsWith(' ');
  status.dataset.status=themeSaving?'saving':themeSaveError?'error':invalid?'error':dirty?'unsaved':'saved';
  status.textContent=themeSaving?'Saving Theme...':themeSaveError?'Could Not Save. Try Again.':invalid?(!customThemeName?'Enter A Theme Name':'Check Theme Name And RGB Values'):dirty?'Unsaved Changes':state.preferences.ThemePreset==='Custom'?'Theme Saved':'No Changes';
  button.disabled=themeSaving || invalid || !dirty;
  button.querySelector('span').textContent=themeSaving?'Saving...':'Save Theme';
  button.title=status.textContent;
  button.setAttribute('aria-busy',String(themeSaving));
  const backgroundSave=$('#background-save');
  if(backgroundSave){
    backgroundSave.disabled=themeSaving || !backgroundDraft?.file || JSON.stringify(backgroundDraft)===JSON.stringify(backgroundOptions(state.preferences.ThemeBackground));
    backgroundSave.querySelector('span').textContent=themeSaving?'Saving...':'Save Background';
    backgroundSave.setAttribute('aria-busy',String(themeSaving));
  }
  document.querySelectorAll('[data-theme-color],[data-theme-rgb],#custom-theme-base,#custom-theme-reset,#custom-theme-name,#saved-custom-theme').forEach(el=>el.disabled=themeSaving);
  document.querySelectorAll('[data-background-field],#background-choose,#theme-edit-colors,#theme-edit-background').forEach(el=>el.disabled=themeSaving);
  document.querySelectorAll('#background-remove').forEach(el=>el.disabled=themeSaving || !backgroundDraft?.file);
  document.querySelectorAll('[data-theme-color]').forEach(el=>{
    const i=Number(el.dataset.themeColor);
    el.title=`Choose ${themeFields[i][1]} Color (${customThemeDraft[i].toUpperCase()})`;
  });
}
function renderSettings() {
  const p = state.preferences;
  const f = (label,key,type='number')=>field(label,key,p[key],type,'setting');
  const c = (label,key)=>check(label,key,p[key],'setting');
  const dungeonTitle=text=>String(text).replace(/\b[a-z]/g,char=>char.toUpperCase());
  const df=(label,key,type='number')=>f(dungeonTitle(label),key,type);
  const dungeonSelect=(label,key,choices)=>`<label><span class="field-caption">${esc(dungeonTitle(label))}</span><select data-setting-field="${key}">${choices.map(([value,text])=>`<option value="${value}" ${String(p[key])===String(value)?'selected':''}>${esc(dungeonTitle(text))}</option>`).join('')}</select></label>`;
  const dungeonOrder=(label,key,icon,description)=>{
    const all=String(p[key]||'').split('|'),offset=0,visible=all;
    return `<section class="dungeon-priority-group"><div class="dungeon-group-heading"><div class="dungeon-heading-icon"><i data-lucide="${icon}"></i></div><div><h3>${dungeonTitle(label)}</h3><p>${dungeonTitle(description)}</p></div><span class="dungeon-count">${all.length}</span></div><input type="hidden" data-setting-field="${key}" value="${esc(p[key]||'')}"><div class="dungeon-priority-caption"><span>Highest priority first</span><span>Drag or use the arrows</span></div><ol class="dungeon-priority-list ${key==='DungeonShopPriority'?'dungeon-shop-grid':''}" data-dungeon-list="${key}" data-dungeon-offset="${offset}">${visible.map((name,j)=>{const i=offset+j;return `<li data-dungeon-name="${esc(name)}"><span class="dungeon-drag-handle" title="Drag To Reorder"><i data-lucide="grip-vertical"></i></span><span class="dungeon-rank">${i+1}</span><span class="dungeon-item-name">${esc(dungeonTitle(name))}</span><div class="dungeon-move-buttons"><button data-dungeon-order="${key}" data-item="${i}" data-direction="-1" ${i===0?'disabled':''} title="Move Up" aria-label="Move ${esc(name)} up"><i data-lucide="chevron-up"></i></button><button data-dungeon-order="${key}" data-item="${i}" data-direction="1" ${i===all.length-1?'disabled':''} title="Move Down" aria-label="Move ${esc(name)} down"><i data-lucide="chevron-down"></i></button></div></li>`}).join('')}</ol></section>`;
  };
  $('#settings').innerHTML = `<div class="settings-header"><h1>Settings</h1><span class="settings-feedback" role="status"></span><button class="primary" id="save-settings"><i data-lucide="save"></i>Save Settings</button></div><div class="settings-body"><nav class="settings-nav" aria-label="Settings sections">${[['General','sliders-horizontal'],['Webhooks','send'],['Challenges','swords'],['Dungeons','castle'],['Events','ticket'],['Delays','timer'],['Keybinds','keyboard']].map(([name,icon])=>`<button data-settings="${name}" class="${settingsTab === name ? 'active' : ''}"><i data-lucide="${icon}"></i>${name}</button>`).join('')}</nav><div class="settings-form">
    ${settingsTab === 'General' ? `<section class="settings-section general-settings"><h2>General</h2><div class="general-group"><h3><i data-lucide="server"></i>Session</h3><div class="fields general-fields">${f('Private Server Link','PrivateServer','url')}</div><div class="checks general-toggles">${c('Use Private Server Link','UsePrivateServerLink')}${c('Rejoin Public Servers on Start','PublicRejoin')}</div></div>
      <div class="general-group startup-tutorials"><div class="startup-tutorial-heading"><h3><i data-lucide="graduation-cap"></i>Startup Tutorials</h3><button id="overview-replay"><i data-lucide="presentation"></i>Start Tutorial</button></div><div class="checks general-toggles">${c('Skip Guide Tutorial on Startup','SkipGuideTutorial')}${c('Skip Macro Overview on Startup','SkipMacroOverview')}</div></div>
      <div class="general-group"><h3><i data-lucide="bot"></i>Discord Integration</h3><div class="fields integration-fields">${f('Your Discord User ID','DiscordUserId','text')}${f('Discord Channel ID','DiscordChannel','text')}${f('Discord Bot Token','DiscordToken','password').replace('<label>','<label class="wide">')}</div><div class="checks general-toggles">${c('Enable Discord Integration','DiscordBotEnabled')}</div><div class="discord-connection-row"><span id="discord-connection-state" role="status"></span><button id="discord-test"><i data-lucide="plug-zap"></i>Test Connection</button></div><p id="discord-connection-message" class="discord-connection-message"></p><p id="discord-test-message" class="discord-connection-message" role="status"></p>${discordSetupGuide()}</div></section>` :
      settingsTab === 'Webhooks' ? `<section class="settings-section webhook-settings"><h2>Webhooks</h2><div class="webhook-group"><div class="webhook-heading"><h3><i data-lucide="send"></i>Connection</h3></div><div class="fields webhook-fields">${f('Webhook URL','Webhook','url')}</div><div class="checks webhook-enable">${c('Enable Webhooks','WebhookEnabled')}</div></div><div class="webhook-group"><div class="webhook-heading"><h3><i data-lucide="at-sign"></i>Pings</h3></div><div class="fields webhook-fields">${f('Discord User ID','WebhookDiscordId','text')}</div><div class="checks webhook-enable">${c('Enable Pings','WebhookPingEnabled')}</div></div><div class="webhook-group"><h3><i data-lucide="list-checks"></i>Webhook Content</h3><div class="webhook-content-groups">${[
        ['Match Details',[['Map Name','WebhookShowMap'],['Mode','WebhookShowMode'],['Act / Difficulty','WebhookShowAct'],['Completion Time','WebhookShowCompletion']]],
        ['Session & Challenges',[['Wins / Losses','WebhookShowRecord'],['Session Time','WebhookShowSessionTime'],['Mode Runs','WebhookShowModeRuns'],['Challenge Runs','WebhookShowChallengeRuns'],['Challenge Timers','WebhookShowNext']]]
      ].map(([title,items])=>`<div><h4>${title}</h4><div class="checks">${items.map(([label,key])=>c(label,key)).join('')}</div></div>`).join('')}</div></div></section>` :
      settingsTab === 'Delays' ? `<section class="settings-section delay-settings"><div class="keybind-heading"><h2>Delays <span class="delay-unit">Milliseconds</span></h2><button id="restore-default-delays"><i data-lucide="rotate-ccw"></i>Restore Default Delays</button></div><div class="delay-groups">${[
        ['Game Actions','mouse-pointer',[['Placement','PlacementRetryDelay'],['Stage Click','StageClickDelay'],['Pathing','PathingDelay']]],
        ['Results & Webhooks','camera',[['Victory Screen','VictoryDelay'],['Webhook Screenshot','WebhookScreenshotDelay']]]
      ].map(([title,icon,delays])=>`<div class="delay-group"><h3><i data-lucide="${icon}"></i>${title}</h3><div class="delay-fields">${delays.map(([label,key])=>f(label,key)).join('')}</div></div>`).join('')}</div></section>` :
      settingsTab === 'Challenges' ? `<section class="settings-section challenge-settings"><h2>Challenges</h2><div class="challenge-group"><h3><i data-lucide="calendar-clock"></i>Challenge Toggles</h3><div class="checks">${c('Enable Daily Challenge','DailyChallengeEnabled')}${c('Enable Half Hourly Challenges','ChallengeEnabled')}</div></div><div class="challenge-group"><h3><i data-lucide="list-start"></i>Start Order</h3><div class="fields challenge-fields"><label><span class="field-caption">First Mode${help('ChallengeFirstMode','setting')}</span><select data-setting-field="ChallengeFirstMode"><option value="Challenges" ${p.ChallengeFirstMode==='Challenges'?'selected':''}>Challenge</option><option value="Mode List" ${p.ChallengeFirstMode==='Mode List'?'selected':''}>First Mode</option></select></label></div></div><div class="challenge-group"><h3><i data-lucide="log-out"></i>Match Handling</h3><div class="checks">${c('Force Leave','ChallengeForceLeave')}</div></div></section>` : settingsTab === 'Dungeons' ? `<section class="settings-section dungeon-settings"><div class="dungeon-page-heading"><div><h2>Dungeons</h2></div></div><nav class="dungeon-view-tabs" aria-label="Dungeon settings"><button data-dungeon-view="run" class="${dungeonSettingsView==='run'?'active':''}"><i data-lucide="sliders-horizontal"></i>Team &amp; Encounters</button><button data-dungeon-view="priorities" class="${dungeonSettingsView==='priorities'?'active':''}"><i data-lucide="list-ordered"></i>Priorities</button></nav><div class="dungeon-view-content">${dungeonSettingsView==='run'?`<div class="dungeon-policy-grid dungeon-team-encounters"><section class="dungeon-policy-card"><h3><i data-lucide="users"></i>Team</h3><p>Your Team Applies To Every Dungeon Map.</p><div class="dungeon-fields">${dungeonSelect('Universal team','DungeonTeam',[[0,'None'],...[1,2,3,4,5,6].map(n=>[n,'Team '+n])])}</div></section><section class="dungeon-policy-card"><h3><i data-lucide="sparkles"></i>Encounter Actions</h3><p>Choose How To Handle Shrine Offers.</p><div class="dungeon-fields">${dungeonSelect('Shrine action','DungeonShrineAction',[['Accept','Accept'],['Deny','Deny']])}${dungeonSelect('Chests','DungeonNormalChests',[['End','Keep until last floor'],['Checkpoint','Open along the way']])}<small class="subtle">Keeping chests risks losing them if the dungeon resets.</small></div></section></div>`:`<div class="dungeon-combined-priorities">${dungeonOrder('Room Priority','DungeonRoomPriority','route','Choose Which Rewards To Pursue First.')}${dungeonOrder('Shop Priority','DungeonShopPriority','shopping-bag','Drag Items To Set Their Purchase Order.')}</div>`}</div><p class="dungeon-manual-note"><i data-lucide="info"></i>Shop Buys One Priority Item. Shrine Uses Your Selected Action.</p></section>` : settingsTab === 'Events' ? `<section class="settings-not-implemented"><strong>NOT IMPLEMENTED YET</strong></section>` :
      `<section class="settings-section keybind-settings"><div class="keybind-heading"><h2>Keybinds</h2><button id="restore-default-keybinds"><i data-lucide="rotate-ccw"></i>Restore Default Keybinds</button></div>${[
        ['Macro Controls','power',[['Start','StartKey'],['Pause / Resume','PauseKey'],['Restart Macro','RestartKey'],['Close Macro','CloseKey']]],
        ['Game Tools','scan',[['Replace Map Image','CaptureKey'],['Zoomtech','ZoomtechKey'],['Test Webhook','WebhookTestKey']]],
        ['Recorder','video',[['Record / Stop','RecordKey'],['Test / Stop Recording','RecordingTestKey']]]
      ].map(([title,icon,bindings])=>`<div class="keybind-group"><h3><i data-lucide="${icon}"></i>${title}</h3><div class="keybind-fields">${bindings.map(([label,key])=>keybindField(label,key)).join('')}</div></div>`).join('')}</section>`}
    </div></div>`;
  icons();
  initPriorityDrag();
  initDungeonPriorityDrag();
  updateFeedback();
  updateDiscordConnection();
}
function updateDiscordConnection() {
  const label = $('#discord-connection-state');
  if (!label) return;
  const discord = state.discord || {state:'Disabled'};
  label.textContent = discord.state;
  label.dataset.state = discord.state;
  $('#discord-connection-message').textContent = discord.message || '';
  $('#discord-test-message').textContent = discord.testMessage || '';
  $('#discord-test-message').classList.toggle('error',!!discord.testFailed);
  $('#discord-test').disabled = !!discord.testing;
}
let detectionId = 'start';
document.addEventListener('change', event => {
  if (event.target.id === 'detection-choice') { detectionId = event.target.value; renderDetection(); }
});
let detectionRevision = -1;
function renderDetection() {
  const data = state.detection;
  detectionRevision = data?.revision ?? null;
  const images = (data?.items || []).filter(item => ['Image','Lettering'].includes(item.kind));
  if (!images.length) { $('#panel').innerHTML = '<section class="detection-editor"><div class="section-title">Detection</div><p class="detection-empty">No Image References</p></section>'; return; }
  const d = images.find(item => item.id === detectionId) || images[0];
  detectionId = d.id;
  const groups = [...new Set(images.map(item=>item.group))];
  const field = (key, label, max) => `<label>${label}<input data-detection-field="${key}" type="number" min="${['w','h','frames'].includes(key) ? 1 : 0}" max="${max}" value="${d[key]}"></label>`;
  $('#panel').innerHTML = `<section class="detection-editor"><div class="section-title">Detection</div>
    <select id="detection-choice" aria-label="Detector">${groups.map(group => `<optgroup label="${esc(group)}">${images.filter(item=>item.group === group).map(item=>`<option value="${item.id}" ${item.id === d.id ? 'selected' : ''}>${esc(item.name)}</option>`).join('')}</optgroup>`).join('')}</select>
    <div class="detection-meta"><span>${esc(d.kind === 'Lettering' ? 'Image Lettering' : 'Image Matching')}</span><span>${d.pending ? 'Capture Preview' : d.override ? 'Custom Reference' : d.image ? 'Default Reference' : 'No Image Reference'}</span></div>
    <div class="detection-preview">${d.image ? `<img src="https://assets.macro.example/${d.image.split('/').map(encodeURIComponent).join('/')}?v=${data.revision}" alt="${esc(d.name)} reference">` : '<div class="detection-empty"><i data-lucide="scan-search"></i><span>No Reference Image</span></div>'}</div>
    ${d.pending ? '<div class="detection-tools"><button data-detection-action="accept"><i data-lucide="check"></i>Use Capture</button><button data-detection-action="discard"><i data-lucide="x"></i>Discard Capture</button></div>' : ''}
    <div class="detection-tools"><button data-detection-action="${data.snipping ? 'cancel' : 'capture'}"><i data-lucide="${data.snipping ? 'x' : 'scissors'}"></i>${data.snipping ? 'Cancel Snip' : 'Capture'}</button><button data-detection-action="replace" ${data.snipping ? 'disabled' : ''}><i data-lucide="image-plus"></i>Replace Image</button><button data-detection-action="test" ${!d.image || d.pending || data.snipping ? 'disabled' : ''}><i data-lucide="scan-search"></i>Test</button><button data-detection-action="reset" ${data.snipping ? 'disabled' : ''}><i data-lucide="rotate-ccw"></i>Restore Default</button></div>
    <p class="detection-result" role="status">${esc(data.resultId === d.id ? data.result : '')}</p>
    <details class="detection-advanced"><summary>Advanced</summary><div class="detection-fields">${field('x','Search X',799)}${field('y','Search Y',598)}${field('w','Width',800)}${field('h','Height',599)}${field('tolerance','Tolerance',255)}${field('frames','Confirmations',5)}</div>${d.id === 'start' ? `<div class="detection-fields">${field('dx','Click Offset X',799)}${field('dy','Click Offset Y',598)}</div>` : ''}<button data-detection-action="save" ${data.snipping ? 'disabled' : ''}><i data-lucide="save"></i>Save Detection Settings</button></details></section>`;
  const preview = $('#panel .detection-preview img');
  if (preview) preview.addEventListener('error', () => {
    const message = document.createElement('span');
    message.className = 'detection-empty';
    message.textContent = 'Reference Image Could Not Be Loaded';
    preview.replaceWith(message);
  }, {once:true});
  icons();
}
function render() {
  if (!state) return;
  prioritySortable?.destroy(); prioritySortable = null;
  surfaceCache.delete('main');
  view = state.page;
  $('#panel').classList.toggle('indexes-panel',view === 'indexes');
  $('#panel').classList.toggle('modes-panel',view === 'gamemodes');
  const settings = ['settings','themes','export','guides'].includes(view);
  $('main').classList.toggle('full-settings',settings); $('#settings').hidden = !settings; $('footer').hidden = settings;
  $('footer').classList.toggle('main-footer',view === 'main' || view === 'detection' || view === 'recorder');
  $('footer').classList.toggle('modes-footer',view === 'gamemodes');
  $('footer').classList.toggle('indexes-footer',view === 'indexes');
  $('.mode-controls').hidden = view !== 'gamemodes';
  $('.index-controls').hidden = view !== 'indexes';
  $('.copy-tool').hidden = view !== 'indexes';
  $('#actions-title').textContent = view === 'indexes' ? 'Index Tools' : 'Action Tools';
  $('#reset-config').hidden = view !== 'indexes';
  $('#copy-category').hidden = view !== 'indexes' || state.preferences.Mode === 'Events';
  document.querySelectorAll('[data-view]').forEach(b => { b.classList.toggle('active',b.dataset.view === view); b.setAttribute('aria-current',b.dataset.view === view ? 'page' : 'false'); });
  if (view === 'guides') renderGuides(); else if (view === 'export') renderExport(); else if (view === 'themes') renderThemes(); else if (settings) renderSettings(); else if (view === 'recorder') renderRecorder(); else if (view === 'detection') renderDetection(); else if (view === 'indexes') renderIndexes(); else if (view === 'gamemodes') renderModes(); else renderMain();
  updateSurface();
  acknowledgeRenderedPage();
  scheduleLayout();
  promptForSetup();
}
function updateSurface() {
  if (!state) return;
  const p = state.preferences;
  applyTheme();
  textWhenChanged($('#run-count'),`${state.batchRuns} / ${p.Runs}`);
  updateFeedback();
  updateDiscordConnection();
  const scopeChoices = ['Infinity Mansion','Dungeons'].includes(p.Mode) ? ['Challenges','Infinity Mansion','Dungeons'] : ['Current Mode','Challenges','Infinity Mansion','Dungeons'];
  replaceWhenChanged('#scope',options(scopeChoices,state.scope));
  if (document.activeElement !== $('#scope')) $('#scope').value = state.scope;
  const currentMode = state.mapName || p.Map || 'No Mode Selected';
  const choices = state.scope === 'Dungeons' ? state.dungeonMaps : state.scope === 'Infinity Mansion' ? state.mansionMaps : state.scope === 'Challenges' ? state.challengeMaps : state.scope === 'Infinity Castle' ? state.castleMaps : [currentMode];
  replaceWhenChanged('#config-choice',options(choices, state.scope !== 'Current Mode' ? p.Map : currentMode));
  $('#config-choice').disabled = state.scope === 'Current Mode';
  $('#config-choice').hidden = false;
  $('#team').closest('.team-field').hidden = p.Mode === 'Dungeons';
  if (document.activeElement !== $('#team')) $('#team').value = p.Team;
  syncProcessLog(state.log);
  textWhenChanged($('#game-title'),state.picking ? 'Map / ' + state.mapName : 'Current Game');
  $('.game-empty').hidden = state.connected || state.picking;
  $('#map-image').hidden = !state.picking;
  if (state.picking) {
    const source = 'https://assets.macro.example/' + state.mapImage.split('/').map(encodeURIComponent).join('/') + '?v=' + state.imageVersion;
    if ($('#map-image').src !== source) $('#map-image').src = source;
  }
  $('.game').classList.toggle('picking',!!state.picking);
  replaceWhenChanged('.markers',state.picking ? state.indexes.filter(x=>x.configured && x.x >= 0 && x.y >= 0).map(x=>`<span class="marker ${x.number === state.selected ? 'selected' : ''}" style="left:${x.x / state.mapWidth * 100}%;top:${x.y / state.mapHeight * 100}%">${x.number}</span>`).join('') : '');
  document.querySelectorAll('[data-index-move]').forEach(button => {
    const next = state.selected + Number(button.dataset.indexMove);
    button.disabled = indexMoveBusy || view !== 'indexes' || next < 1 || next > state.indexes.length;
  });
  document.querySelectorAll('[data-index]').forEach(button=>button.disabled=indexMoveBusy);
  updateModeControls();
}
function applyState(next) {
  if(Number.isInteger(next.stateRevision)&&Number.isInteger(state?.stateRevision)&&next.stateRevision<state.stateRevision)return;
  if(Number.isInteger(next.pageGeneration) && Number.isInteger(state?.pageGeneration) && next.pageGeneration<state.pageGeneration)return;
  const newerModeDraft = (modeDirty || modeSaving || savedSelection) && next.page === 'gamemodes' && view === 'gamemodes' ? structuredClone(draftMode) : null;
  if (state && next.page !== state.page) { feedback = ''; feedbackError = false; }
  const redraw = !state || next.page !== state.page || next.pageGeneration !== state.pageGeneration || next.selected !== state.selected || next.configPath !== state.configPath || next.taskIndex !== state.taskIndex;
  state = next;
  if (redraw) {
    indexDirty = false;
    if (!newerModeDraft) { modeDirty = false; draftMode = null; savedSelection = null; }
    render();
    if (newerModeDraft && view === 'gamemodes') { draftMode = newerModeDraft; renderModes(false); }
  }
  else {
    updateSurface();
    if (view === 'main') {
      const signature = JSON.stringify([state.mapName,state.preferences.Mode,state.preferences.Act,state.preferences.Difficulty,state.preferences.ChallengeEnabled,state.preferences.DailyChallengeEnabled,state.preferences.BossRushMode,state.preferences.MakimaCard,state.stats,state.wins,state.losses]);
      if (surfaceCache.get('main') !== signature) { surfaceCache.set('main',signature); renderMain(); }
    }
    if (view === 'indexes') syncIndexTiles();
    if (view === 'gamemodes') updateModeRows();
    if (view === 'detection' && detectionRevision !== (state.detection?.revision ?? null)) renderDetection();
    if (view === 'recorder') updateRecorder();
  }
  syncTutorialNavigation();
}
bridge?.addEventListener('message', e => {
  const message = e.data;
  if (message.id && requests.has(message.id)) {
    const pending = requests.get(message.id); clearTimeout(pending.timer); requests.delete(message.id);
    message.error ? pending.reject(new Error(message.error)) : pending.resolve(message);
  }
  if (message.state) {
    try { applyState(message.state); }
    catch(error) { report(new Error('Could not refresh the interface: ' + error.message)); }
  }
});
function updateModeRows() {
  const rows = document.querySelectorAll('.mode-row');
  if (rows.length !== state.modes.length) { renderModes(false); return; }
  rows.forEach((row,i) => {
    const mode = state.modes[i];
    row.classList.toggle('active',i + 1 === selectedModeRow);
    row.dataset.modeRow = i + 1;
    textWhenChanged(row.querySelector('strong'),mode.mode==='Portals'?mode.portalName:mode.mode==='Dungeons'?'Dungeons':mode.mode==='Infinity Mansion'?'Infinity Mansion':mode.mode==='Infinity Castle'?'Infinity Castle':mode.map);
    textWhenChanged(row.querySelector('small'),modeCardSubtitle(mode));
    textWhenChanged(row.querySelector('.mode-runs'),`${mode.runs} ${Number(mode.runs) === 1 ? 'run' : 'runs'}`);
  });
}
function syncIndexTiles() {
  const grid=$('.index-grid');
  if(!grid)return;
  const html=indexTiles();
  if(grid.tileSignature===html)return;
  grid.tileSignature=html;
  const template=document.createElement('template');
  template.innerHTML=html;
  const existing=new Map([...grid.querySelectorAll('[data-index]')].map(button=>[button.dataset.index,button]));
  const nodes=[...template.content.children].map(next=>{
    const button=existing.get(next.dataset.index);
    if(!button)return next;
    button.className=next.className;
    button.setAttribute('aria-pressed',next.getAttribute('aria-pressed'));
    button.title=next.title;
    if(button.innerHTML!==next.innerHTML)button.innerHTML=next.innerHTML;
    return button;
  });
  if(nodes.length!==grid.children.length||nodes.some((node,i)=>grid.children[i]!==node))grid.replaceChildren(...nodes);
}
function values(attribute) {
  const result = {};
  document.querySelectorAll(`[data-${attribute}-field]`).forEach(el => {
    const key = el.dataset[attribute + 'Field'];
    result[key] = el.dataset.keybindPrevious !== undefined || (attribute==='setting'&&(keybindDrafts.has(key)||keybindMessages.get(key)?.error)) ? state.preferences[key] : el.type === 'checkbox' ? Number(el.checked)
      : attribute === 'index' && ['wave','wait','domainWave','domainWait'].includes(key) && el.value === '' && !el.validity.badInput ? '0' : el.value;
  });
  return result;
}
async function saveIndex() {
  if (configResetBusy) return;
  if (indexSaving) { await indexSaving; return saveIndex(); }
  if (!indexDirty || view !== 'indexes') return;
  const revision = indexRevision;
  const data = {index:state.selected, fields:values('index')};
  indexSaving = request('index.update',data);
  try { await indexSaving; if (indexRevision === revision) indexDirty = false; updateSurface(); }
  finally { indexSaving = null; }
  if (indexDirty) return saveIndex();
}
async function saveSettings() {
  if (settingsSaving) { await settingsSaving; return saveSettings(); }
  if (!settingsDirty) return;
  const revision = settingsRevision;
  settingsSaving = request('settings.update',{fields:values('setting')});
  try { await settingsSaving; if (settingsRevision === revision) settingsDirty = false; }
  finally { settingsSaving = null; }
  if (settingsDirty) return saveSettings();
}
async function saveMode() {
  if (modeSaving) { await modeSaving; return saveMode(); }
  if (!draftMode || view !== 'gamemodes') return;
  const revision = modeRevision;
  modeSaving = request('mode.update',structuredClone(draftMode));
  try { await modeSaving; if (modeRevision === revision) modeDirty = false; }
  finally { modeSaving = null; }
  if (modeRevision !== revision) { toast('Selection saved; new edits are unsaved'); return; }
  const edited = !!state.taskIndex;
  if (edited) await request('mode.new');
  if (edited) selectedModeRow = 0;
  savedSelection = edited ? null : structuredClone(draftMode);
  toast(edited ? 'Changes saved' : 'Selection saved');
  updateModeControls();
  updateModeRows();
}
window.flushEdits = async () => {
  await Promise.all([...pendingKeybindSaves.values()]);
  clearTimeout(editTimer);
  const errors = [];
  try { await saveIndex(); } catch(error) { errors.push(error.message); }
  try { await saveSettings(); } catch(error) { errors.push(error.message); }
  if (errors.length) throw new Error(errors.join('\n'));
};
function updateCardSelectionState() {
  const busy=!!pendingCardSelection;
  document.querySelectorAll('[data-index-field],[data-mode-field],#pick,#reset-index,#copy-confirm,[data-index-move],#save-selection,#add-mode,#delete-mode,[data-mode-move]').forEach(el=>{
    if(busy && !el.disabled){el.dataset.cardLocked='true';el.disabled=true;}
    else if(!busy && el.dataset.cardLocked){el.disabled=false;delete el.dataset.cardLocked;}
  });
  if(pendingCardSelection?.kind==='index'){
    const grid=$('.index-grid');
    if(grid)grid.tileSignature=null;
    document.querySelectorAll('[data-index]').forEach(el=>{
      const active=Number(el.dataset.index)===pendingCardSelection.index;
      el.classList.toggle('active',active);el.setAttribute('aria-pressed',String(active));
    });
  }
}
async function selectCard(kind,index) {
  if(pendingCardSelection?.kind===kind && pendingCardSelection.index===index)return cardSelectionPromise;
  if(!pendingCardSelection && (kind==='index'?state.selected===index:state.taskIndex===index && !draftMode))return;
  pendingCardSelection={kind,index};
  if(kind==='mode'){selectedModeRow=index;updateModeRows();}
  updateCardSelectionState();
  if(cardSelectionPromise)return cardSelectionPromise;
  let selectionFailed=false;
  cardSelectionPromise=(async()=>{
    try {
      await window.flushEdits();
      while(pendingCardSelection){
        const target=pendingCardSelection;
        if(target.kind==='mode'){savedSelection=null;draftMode=null;}
        await request(target.kind+'.select',{index:target.index});
        if(pendingCardSelection===target)pendingCardSelection=null;
      }
    } catch(error){pendingCardSelection=null;selectionFailed=true;throw error;}
    finally {
      cardSelectionPromise=null;
      updateCardSelectionState();
      if(!selectionFailed && view==='indexes')renderIndexes();
      else if(!selectionFailed && view==='gamemodes')renderModes(false);
      else if(view==='indexes')syncIndexTiles();
      else if(view==='gamemodes'){draftMode=null;modeDirty=false;selectedModeRow=state.taskIndex;renderModes(true);}
      updateSurface();
    }
  })();
  return cardSelectionPromise;
}
async function navigateTo(page) {
  pendingNavigation=page;
  if(navigationPromise)return navigationPromise;
  navigationPromise=(async()=>{
    try {
      if(cardSelectionPromise)await cardSelectionPromise;
      await window.flushEdits();
      while(pendingNavigation!==null){
        const target=pendingNavigation;
        pendingNavigation=null;
        if(target!==state.page)await request('navigate',{page:target});
      }
    } finally {pendingNavigation=null;navigationPromise=null;}
  })();
  return navigationPromise;
}
window.startMacro = async () => { try { await window.flushEdits(); await request('start'); } catch(e) { report(e); } };
window.showAprilStartReminder = async () => {
  const dialog=$('#april-start-dialog');
  if(dialog.open){$('#april-start-confirm').focus();return;}
  await request('ui.modal',{visible:true});
  try {icons();dialog.showModal();$('#april-start-confirm').focus();}
  catch(error){await request('ui.modal',{visible:false});report(error);}
};
window.closeAprilStartReminder = () => {const dialog=$('#april-start-dialog');if(dialog.open)dialog.close();};
async function finishAprilStartReminder(confirm){
  const button=$('#april-start-confirm');
  if(button.disabled)return;
  button.disabled=true;
  try {
    window.closeAprilStartReminder();
    await request('ui.modal',{visible:false});
    await request('start',confirm?{aprilConfirm:true}:{aprilCancel:true});
  } catch(error){report(error);}
  finally {button.disabled=false;}
}
$('#april-start-dialog').addEventListener('cancel',event=>{event.preventDefault();finishAprilStartReminder(false);});
function showPreflight(issues) {
  $('#preflight-issues').innerHTML=issues.map((issue,index)=>`<div class="preflight-issue"><p>${esc(issue.message)}</p><button data-preflight-fix="${index+1}"><i data-lucide="wrench"></i>Fix</button></div>`).join('');
  icons();
  const dialog=$('#preflight-dialog');
  if(!dialog.open)dialog.showModal();
}
window.closeMacro = async () => { try { await window.flushEdits(); await request('close'); } catch(e) { report(e); } };
window.restartMacro = async () => { try { await window.flushEdits(); } catch(e) { report(e); } try { await request('restart'); } catch(e) { report(e); } };
window.pauseMacro = async () => { try { await request('pause'); } catch(e) { report(e); } };
document.addEventListener('pointerdown', e => {
  const active = document.activeElement;
  if (active?.matches('input, select, textarea') && !e.target.closest('input, select, textarea')) active.blur();
});
document.addEventListener('click', async e => {
  const exportRow = e.target.closest('.export-config-row');
  if (exportRow && !e.target.closest('input, select, textarea, button, a')) {
    const toggle = exportRow.querySelector('input[type=checkbox]');
    if (toggle && !toggle.disabled && !configShareBusy) toggle.click();
    return;
  }
  const label = e.target.closest('label');
  if (label && !e.target.closest('input, select, textarea, button, a')) e.preventDefault();
  const b = e.target.closest('button');
  const modeRow = e.target.closest('.mode-row');
  if (!b && modeRow && state) {
    selectedModeRow = Array.from(document.querySelectorAll('.mode-row')).indexOf(modeRow) + 1;
    updateModeRows(); updateModeControls(); return;
  }
  if (!b || b.disabled || !state) return;
  if(b.dataset.view&&tutorialNavigationLocked())return;
  if (b.dataset.setupGuide !== undefined) {
    const next=Number(b.dataset.setupGuide);
    if(Number.isInteger(next)&&next>=0&&next<SETUP_GUIDES.length&&next!==selectedSetupGuide){selectedSetupGuide=next;renderGuides();}
    return;
  }
  if (b.id === 'setup-open-guides') {
    b.disabled=true;
    try {await window.flushEdits();await request('navigate',{page:'guides'});$('#setup-required-dialog').close();}
    catch(error){report(error);}finally{b.disabled=false;}
    return;
  }
  if (b.id === 'guides-reviewed' || b.id === 'setup-already-correct') {
    b.disabled=true;
    try {
      await request('guides.reviewed');
      if(b.id==='setup-already-correct')$('#setup-required-dialog').close();
      if(state.page==='guides')renderGuides();
      promptForOverview();
    }
    catch(error){report(error);b.disabled=false;}
    return;
  }
  if (b.id === 'guide-enlarge') {
    const guide=SETUP_GUIDES[selectedSetupGuide];
    $('#guide-image-title').textContent=guide.title;
    $('#guide-large-image').src='GuideImages/'+guide.image;
    $('#guide-large-image').alt=guide.title+' reference';
    $('#guide-image-dialog').showModal();return;
  }
  if (b.id === 'guide-image-close') {$('#guide-image-dialog').close();return;}
  if (await handleOverviewClick(b)) return;
  if(['restore-default-keybinds','restore-default-delays'].includes(b.id)){
    b.disabled=true;clearTimeout(editTimer);
    try{
      await Promise.all([...pendingKeybindSaves.values()]);
      if(settingsSaving)await settingsSaving.catch(()=>{});
      const keybinds=b.id==='restore-default-keybinds';
      await request(keybinds?'keybinds.reset':'delays.reset');settingsDirty=false;settingsRevision++;if(keybinds){keybindMessages.clear();keybindDrafts.clear();}renderSettings();updateFeedback();
    }catch(error){report(error);b.disabled=false;}
    return;
  }
  if(b.dataset.openFolder){
    try {await request('folder.open',{folder:b.dataset.openFolder});}
    catch(error){report(error);}
    return;
  }
  if(b.dataset.themePreviewPage){
    if(b.dataset.themePreviewPage!==customPreviewPage){customPreviewPage=b.dataset.themePreviewPage;renderCustomPreviewPage();}
    return;
  }
  if(b.closest('#custom-theme-preview'))return;
  if(b.id==='april-start-confirm'){await finishAprilStartReminder(true);return;}
  if(b.id==='april-start-close'){await finishAprilStartReminder(false);return;}
  if(b.id==='preflight-close'){$('#preflight-dialog').close();return;}
  if(b.dataset.preflightFix){
    b.disabled=true;
    try {
      await window.flushEdits();
      await request('start.fix',{issue:Number(b.dataset.preflightFix)});
      if(view==='gamemodes'){selectedModeRow=state.taskIndex;draftMode=null;renderModes(true);}
      $('#preflight-dialog').close();
    } catch(error){report(error);}
    finally{b.disabled=false;}
    return;
  }
  if(b.dataset.view===view && !navigationPromise)return;
  if(b.dataset.settings===settingsTab)return;
  if(b.dataset.editorPage && Number(b.dataset.editorPage)===editorPage)return;
  if(b.id==='theme-show-custom' && customThemeOpen)return;
  if(b.id==='theme-show-presets' && !customThemeOpen)return;
  if(b.id==='theme-edit-colors' && !backgroundEditorOpen)return;
  if(b.id==='theme-edit-background' && backgroundEditorOpen)return;
  if(b.dataset.presetChoice && b.dataset.presetChoice===state.preferences.ThemePreset)return;
  if(b.dataset.mode && !pendingCardSelection && Number(b.dataset.mode)===state.taskIndex && !draftMode)return;
  if (indexMoveBusy && (b.dataset.index || b.dataset.indexMove || b.dataset.editorPage || b.dataset.view || ['reset-index','reset-config','copy-confirm','pick'].includes(b.id))) return;
  if (b.dataset.indexMove) {
    indexMoveBusy = true;
    const index = state.selected;
    updateSurface();
    try {
      await window.flushEdits();
      await request('index.move',{index,direction:Number(b.dataset.indexMove)});
      renderIndexes();
    } catch(error) { report(error); }
    finally { indexMoveBusy = false; updateSurface(); }
    return;
  }
  try {
    if(b.id==='cancel-share-import'){$('#import-confirm-dialog').close();return;}
    if(b.id==='confirm-share-import'){
      if(configShareBusy)return;
      configShareBusy=true;b.disabled=true;
      try{
        const imported=await request('share.import',{queuePolicy:$('#import-queue-policy').value,conflict:$('#import-conflict-policy').value,applySettings:$('#import-apply-settings').checked});
        savedThemes=null;customThemeName=null;customThemeDraft=null;
        indexDirty=false;modeDirty=false;draftMode=null;savedSelection=null;selectedModeRow=0;exportCatalog=null;
        $('#import-confirm-dialog').close();
        if(view==='export')await loadExportConfigs();else render();
        toast(`Config imported — ${imported.result.configs} config${imported.result.configs===1?'':'s'} imported`+(imported.result.warnings?.length?' '+imported.result.warnings.join(' '):''));
      }catch(error){report(error);}
      finally{configShareBusy=false;b.disabled=false;}
      return;
    }
    if(b.id==='refresh-export-configs'){await window.flushEdits();invalidateExportCode();await loadExportConfigs();return;}
    if (['generate-config-code','copy-config-code'].includes(b.id)) {
      if(configShareBusy)return;
      configShareBusy=true;b.disabled=true;
      if(b.id==='generate-config-code') {
        $('#config-export-message').textContent='Uploading Configs...';
        document.querySelectorAll('[data-export-group],[data-export-config],[data-export-recording],[data-export-theme],#export-mode-list,#export-safe-settings,#select-all-export-configs,#export-config-mode,#export-config-search,#refresh-export-configs,#copy-config-code').forEach(el=>el.disabled=true);
      }
      try {
        await window.flushEdits();
        if(b.id==='generate-config-code') {
          const reply=await request('share.export',{configs:[...selectedExportConfigs],recordings:[...selectedExportRecordings],customThemes:[...selectedExportThemes],modes:$('#export-mode-list').checked,settings:$('#export-safe-settings').checked,themes:false});
          exportedConfigCode=reply.result.code;
          $('#export-config-code').value=exportedConfigCode;$('#copy-config-code').disabled=false;
          $('#config-code-size').textContent=exportedConfigCode.length+' characters';
          $('#config-export-message').textContent=exportedConfigCode.startsWith('CAPY-')?'Code ready.':exportedConfigCode.length>1900?'This code may exceed Discord\'s message limit. Send it as a text attachment, or export a smaller bundle.':'Code ready to copy.';
          if(reply.result.warnings?.length)$('#config-export-message').textContent+=' '+reply.result.warnings.join(' ');
        } else if(b.id==='copy-config-code') {
          await request('share.copy',{code:exportedConfigCode});$('#config-export-message').textContent='Code copied.';
        }
      } catch(error) {
        const message=$('#config-export-message');
        if(message)message.textContent=error.message;
        else report(error);
      } finally {
        configShareBusy=false;b.disabled=false;
        document.querySelectorAll('[data-export-group],[data-export-config],[data-export-recording],[data-export-theme],#export-mode-list,#export-safe-settings,#select-all-export-configs,#export-config-mode,#export-config-search,#refresh-export-configs').forEach(el=>el.disabled=false);
        if($('#copy-config-code'))$('#copy-config-code').disabled=!exportedConfigCode;
      }
      return;
    }
    if(b.id==='import-config') {
      if(configShareBusy)return;
      configShareBusy=true;b.disabled=true;b.setAttribute('aria-busy','true');
      try {
        await window.flushEdits();
        await request('share.preview');
        const imported=await request('share.import',{queuePolicy:'append',conflict:'replace',applySettings:true});
        toast(`Config imported — ${imported.result.configs} config${imported.result.configs===1?'':'s'} imported`+(imported.result.warnings?.length?' '+imported.result.warnings.join(' '):''));

      } catch(error) {report(error);}
      finally {
        configShareBusy=false;
        const button=$('#import-config');
        if(button){button.disabled=false;button.removeAttribute('aria-busy');}
      }
      return;
    }
    if(b.id==='theme-show-custom'){customThemeOpen=true;renderThemes();return;}
    if(b.id==='theme-show-presets'){customThemeOpen=false;renderThemes();return;}
    if(b.id==='theme-edit-colors' || b.id==='theme-edit-background'){backgroundEditorOpen=b.id==='theme-edit-background';renderThemes();return;}
    if(b.id==='background-choose'){
      if(backgroundChoosing)return;
      backgroundChoosing=true;b.disabled=true;
      try {
        const reply=await request('theme.background.choose');
        if(!reply.result.cancelled){
          const previous=backgroundDraft;
          backgroundDraft=backgroundOptions(reply.result.background);
          themeSaving=true;themeSaveError=false;renderThemes();
          try {
            const applied=await request('theme.background.set',{background:backgroundDraft});
            savedThemes=applied.result?.themes || savedThemes;
          } catch(error){backgroundDraft=previous;themeSaveError=true;throw error;}
          finally {themeSaving=false;renderThemes();}
        }
      } finally {backgroundChoosing=false;b.disabled=false;}
      return;
    }
    if(b.id==='background-remove'){
      if(themeSaving)return;
      const previous=backgroundDraft;
      themeSaving=true;backgroundRemoving=true;backgroundDraft=defaultBackground();renderThemes();
      try {
        const reply=await request('theme.background.remove');
        savedThemes=reply.result?.themes || savedThemes;themeSaveError=false;
      } catch(error){backgroundDraft=previous;themeSaveError=true;report(error);}
      finally {themeSaving=false;backgroundRemoving=false;renderThemes();}
      return;
    }
    if(b.id==='background-save'){
      if(themeSaving)return;
      themeSaving=true;updateCustomThemeState();
      try {
        const reply=await request('theme.background.set',{background:backgroundDraft});
        savedThemes=reply.result?.themes || savedThemes;themeSaveError=false;
      } catch(error){report(error);}
      finally {themeSaving=false;updateCustomThemeState();}
      return;
    }
    if(b.id==='custom-theme-reset' || b.id==='save-custom-theme') {
      if(themeSaving)return;
      const resetting=b.id==='custom-theme-reset';
      const colors=resetting ? [...themePresets[customThemeBase]] : [...customThemeDraft];
      await saveNamedTheme(colors,customThemeName,resetting);
      return;
    }
    if (b.dataset.presetChoice) {
      await window.flushEdits();
      await request('theme.set',{preset:b.dataset.presetChoice});
      customThemeBase=b.dataset.presetChoice;
      customThemeDraft=[...themePresets[customThemeBase]];
      themeSaveError=false;
      applyTheme(); renderThemes(); return;
    }
    if (b.id === 'copy-category') {
      if(categoryCopyBusy)return;
      categoryCopyBusy=true;b.disabled=true;
      try {
        await window.flushEdits();
        const reply=await request('config.category.preview',{path:state.configPath});
        categoryCopyPreview=reply.result;
        $('#copy-category-summary').textContent=`Category: ${categoryCopyPreview.category}. ${categoryCopyPreview.count} other configs; ${categoryCopyPreview.overwrites} already have configured indexes.`;
        $('#copy-category-targets').innerHTML=categoryCopyPreview.names.map(name=>`<li>${esc(name)}</li>`).join('');
        await request('ui.modal',{visible:true});
        try {$('#copy-category-dialog').showModal();}
        catch(error){await request('ui.modal',{visible:false});throw error;}
      } finally {categoryCopyBusy=false;b.disabled=false;}
      return;
    }
    if(b.id==='cancel-category-copy') {$('#copy-category-dialog').close();categoryCopyPreview=null;return;}
    if(b.id==='confirm-category-copy') {
      if(categoryCopyBusy || !categoryCopyPreview)return;
      categoryCopyBusy=true;b.disabled=true;$('#cancel-category-copy').disabled=true;
      try {
        await window.flushEdits();
        await request('config.category.copy',{id:categoryCopyPreview.id});
        $('#copy-category-dialog').close();categoryCopyPreview=null;
      } finally {categoryCopyBusy=false;b.disabled=false;$('#cancel-category-copy').disabled=false;}
      return;
    }
    if (b.id === 'reset-config') { resetConfigPath = state.configPath; $('#reset-config-dialog').showModal(); return; }
    if (b.id === 'cancel-config-reset') { $('#reset-config-dialog').close(); return; }
    if (b.id === 'confirm-config-reset') {
      if (configResetBusy) return;
      configResetBusy = true; b.disabled = true; $('#cancel-config-reset').disabled = true;
      clearTimeout(editTimer);
      try {
        if (indexSaving) await indexSaving.catch(()=>{});
        await request('config.reset',{path:resetConfigPath});
        indexDirty = false; indexRevision++; renderIndexes(); $('#reset-config-dialog').close();
      } finally { configResetBusy = false; b.disabled = false; $('#cancel-config-reset').disabled = false; }
      return;
    }
    if (b.id === 'keep-selection') { pendingModeAction = null; $('#unsaved-selection').close(); $('#save-selection').focus(); return; }
    if (b.id === 'discard-selection') {
      const action = pendingModeAction;
      pendingModeAction = null;
      $('#unsaved-selection').close();
      modeDirty = false; savedSelection = null; modeRevision++;
      // Visible mode controls must always have a draft, including when editing the same card.
      draftMode = modeDraft();
      renderModes(false); updateFeedback();
      if (action?.dataset.mode) await selectCard('mode',Number(action.dataset.mode));
      else action?.click();
      return;
    }
    if (view === 'gamemodes' && modeDirty && (b.dataset.view || b.dataset.mode || b.id === 'new-selection' || (b.id === 'add-mode' && state.taskIndex) || b.dataset.modeMove || b.id === 'delete-mode')) {
      pendingModeAction = b; $('#unsaved-selection').showModal();
      const r = $('#panel').getBoundingClientRect(); $('#unsaved-selection').style.left = (r.left + 16) + 'px'; $('#unsaved-selection').style.top = (r.top + 24) + 'px'; return;
    }
    if (b.dataset.detectionAction) {
      const action = b.dataset.detectionAction;
      const data = {id:detectionId};
      const detector = state.detection.items.find(item=>item.id===detectionId);
      if (action === 'save' && detector.kind === 'Image') ['cx','cy','cw','ch'].forEach(key=>data[key]=detector[key]);
      if (action === 'save') document.querySelectorAll('[data-detection-field]').forEach(input => {
        if (input.value === '' || !input.checkValidity()) throw new Error('Enter valid detection settings');
        data[input.dataset.detectionField] = Number(input.value);
      });
      document.querySelectorAll('[data-detection-action]').forEach(button=>button.disabled=true);
      try { await request('detection.' + action,data); } finally { renderDetection(); }
      return;
    }
    if (b.classList.contains('contract-handle') || b.closest('.setting-help')) return;
    if (b.dataset.discordGuide) {
      const content = $('.discord-guide-content'), form = $('.settings-form'), scrollTop = form.scrollTop;
      discordGuideIndex = Math.max(0,Math.min(3,discordGuideIndex + Number(b.dataset.discordGuide)));
      content.innerHTML = discordGuideStep();
      icons();
      $('.discord-guide-step-heading h3').focus({preventScroll:true});
      form.scrollTop = scrollTop;
      return;
    }
    if (b.id === 'discord-guide-done') {
      $('.discord-setup-guide').open = false;
      discordGuideIndex = 0;
      $('.discord-guide-content').innerHTML = discordGuideStep();
      icons();
      $('.discord-setup-guide summary').focus({preventScroll:true});
      return;
    }
    if (b.id === 'minimize') { await request('minimize'); return; }
    if (b.id === 'close') { window.closeMacro(); return; }
    if (b.id === 'clear-log') { await request('log.clear'); return; }
    if (b.id === 'recording-save') {
      const name = $('#recording-name').value.trim();
      if (!name) { $('#recording-name').focus(); toast('Enter a recording name before saving',true); return; }
      await request('recorder.save',{name}); recorderDraftName = state.recorder.name.replace(/\.txt$/i,''); toast('Recording saved'); return;
    }
    if (b.id === 'recording-discard') { await request('recorder.discard'); recorderDraftName = ''; renderRecorder(); return; }
    if (b.id === 'recording-load') { await request('recorder.load',{name:recorderFile}); recorderDraftName = state.recorder.name.replace(/\.txt$/i,''); renderRecorder(); return; }
    if (b.id === 'recording-edit') { await request('recorder.open',{name:recorderFile}); return; }
    if(b.dataset.dungeonView){await saveSettings();dungeonSettingsView=b.dataset.dungeonView;renderSettings();return;}
    if(b.dataset.dungeonShopPage!==undefined){await saveSettings();dungeonShopPage=Number(b.dataset.dungeonShopPage);renderSettings();return;}
    if(b.dataset.dungeonOrder){
      if(b.dataset.dungeonOrder==='DungeonShopPriority')dungeonShopScrollTop=document.querySelector('.dungeon-shop-grid').scrollTop;
      await saveSettings();
      const key=b.dataset.dungeonOrder,order=String(state.preferences[key]).split('|'),from=Number(b.dataset.item),to=from+Number(b.dataset.direction);
      if(to<0||to>=order.length)return;
      [order[from],order[to]]=[order[to],order[from]];

      await request('settings.update',{fields:{[key]:order.join('|')}});renderSettings();return;
    }
    if (b.dataset.settings) { await saveSettings(); settingsTab = b.dataset.settings; renderSettings(); return; }
    if(b.dataset.index || b.dataset.mode){await selectCard(b.dataset.index?'index':'mode',Number(b.dataset.index||b.dataset.mode));return;}
    if(b.dataset.view){await navigateTo(b.dataset.view);return;}
    if(cardSelectionPromise)await cardSelectionPromise;
    await window.flushEdits();
    if (b.dataset.editorPage) { editorPage = Number(b.dataset.editorPage); renderIndexes(); }
    else if (b.id === 'reset-index') { await request('index.reset'); renderIndexes(); }
    else if (b.id === 'copy-confirm') {
      const source = $('#copy-source'), target = $('#copy-target');
      if (!source.value || !target.value || !source.checkValidity() || !target.checkValidity()) throw Error('Enter source and destination indexes from 1 to 90');
      const from = Number(source.value), to = Number(target.value);
      await request('index.copy',{source:from,destination:to}); source.value = ''; target.value = ''; renderIndexes(); toast(`Index ${from} copied to ${to}`);
    }
    else if (b.id === 'pick') { await request(state.picking ? 'coordinates.cancel' : 'coordinates.begin'); renderIndexes(); sendLayout(); }
    else if (b.dataset.modeMove) { const destination = selectedModeRow + Number(b.dataset.modeMove); await request('mode.move',{index:selectedModeRow,direction:Number(b.dataset.modeMove)}); selectedModeRow = destination; updateModeRows(); updateModeControls(); }
    else if (b.id === 'delete-mode') {
      const deleted = selectedModeRow;
      await request('mode.delete',{index:deleted});
      selectedModeRow = Math.min(deleted,state.modes.length);
      updateModeRows(); updateModeControls(); toast('Mode deleted');
    }
    else if (b.id === 'new-selection') { await request('mode.new'); savedSelection = null; draftMode = null; modeDirty = false; renderModes(true); toast('New selection'); }
    else if (b.id === 'save-selection') { await saveMode(); }
    else if (b.id === 'add-mode') {
      if(state.taskIndex){
        await request('mode.new');
        savedSelection=null;draftMode=null;modeDirty=false;selectedModeRow=0;
        renderModes(true);toast('New mode');return;
      }
      if (!draftMode) {renderModes(true);return;}
      const revision = modeRevision, item = structuredClone(draftMode);
      b.disabled = true;
      try {
        await request('mode.add',item);
        selectedModeRow = 0;
        savedSelection = null;
        if (modeRevision === revision) { draftMode = item; modeDirty = false; }
        renderModes(false); toast('Mode added');
      } finally { updateModeControls(); }
    }
    else if (b.id === 'save-modes') { await request('modes.save'); toast('Mode list saved'); }
    else if (b.id === 'save-settings') { toast('Settings saved'); }
    else if (b.id === 'discord-open-portal') { await request('discord.portal'); }
    else if (b.id === 'discord-test') { await request('discord.test'); }
  } catch(error) { if (b.dataset.mode) updateModeRows(); report(error); }
});
document.addEventListener('input', e => {
  if(e.target.id==='export-config-search'){exportConfigQuery=e.target.value;renderExportList();return;}
  if(e.target.id==='log-search'){processLogQuery=e.target.value;renderProcessLog();return;}
  if(['opacity','dim'].includes(e.target.dataset.backgroundField)){
    const key=e.target.dataset.backgroundField;
    backgroundDraft[key]=Number(e.target.value);
    $('#background-'+key+'-value').textContent=e.target.value+'%';
    updateCustomThemePreview();return;
  }
  if(e.target.id==='custom-theme-name'){customThemeName=e.target.value;themeSaveError=false;updateCustomThemeState();return;}
  if(e.target.matches('[data-theme-color],[data-theme-rgb]')) {
    themeSaveError=false;
    const el=e.target, index=Number(el.dataset.themeColor ?? el.dataset.themeRgb);
    if(el.dataset.themeColor!==undefined) {
      customThemeDraft[index]=el.value;
      document.querySelectorAll(`[data-theme-rgb="${index}"]`).forEach(input=>{input.value=parseInt(el.value.slice(1+Number(input.dataset.channel)*2,3+Number(input.dataset.channel)*2),16);input.setCustomValidity('');});
    } else {
      if(el.value==='' || !Number.isInteger(Number(el.value)) || Number(el.value)<0 || Number(el.value)>255){el.setCustomValidity('Enter a whole number from 0 to 255.');updateCustomThemeState();return;}
      el.setCustomValidity('');
      const channels=customThemeDraft[index].match(/[0-9a-f]{2}/gi);
      channels[Number(el.dataset.channel)]=Number(el.value).toString(16).padStart(2,'0');
      customThemeDraft[index]='#'+channels.join('');
      $(`[data-theme-color="${index}"]`).value=customThemeDraft[index];
    }
    $('#save-custom-theme').disabled=!!document.querySelector('.theme-rgb input:invalid');
    updateCustomThemePreview();return;
  }
  const el = e.target;
  if(el.matches('.keybind-fields input'))return;
  if (el.id === 'recording-name') recorderDraftName = el.value;
  if (el.matches('[data-index-field],[data-setting-field],[data-mode-field]')) {feedback=''; feedbackError=false;el.removeAttribute('aria-invalid');}
  if (el.id === 'search') { query = el.value; syncIndexTiles(); }
  if (el.dataset.indexField) { indexDirty = true; indexRevision++; }
  if (el.dataset.settingField) { settingsDirty = true; settingsRevision++; }
  if (el.dataset.modeField) { (draftMode ||= modeDraft())[el.dataset.modeField] = el.value; modeDirty = true; savedSelection = null; modeRevision++; updateModeControls(); updateFeedback(); }
  if (el.matches('[data-index-field],[data-setting-field]')) {
    clearTimeout(editTimer);
    editTimer = setTimeout(()=>window.flushEdits().catch(report),300);
    updateFeedback();
  }
});
document.addEventListener('change', async e => {
  const el = e.target;
  if(el.id==='log-filter'){processLogErrorsOnly=el.value==='errors';renderProcessLog();return;}
  if(el.dataset.keybindPrevious !== undefined)return;
  const keybind=el.matches('.keybind-fields input');
  if(keybind){await saveKeybind(el);return;}
  if(el.id==='saved-custom-theme') {
    const theme=(savedThemes||[]).find(theme=>theme.name===el.value);
    if(theme){backgroundDraft=backgroundOptions(theme.background);await saveNamedTheme(themeFields.map(([key])=>theme.colors[key]),theme.name);}
    return;
  }
  if(el.dataset.backgroundField==='fit'){backgroundDraft.fit=el.value;updateCustomThemePreview();return;}
  if(el.id==='export-config-mode'){exportConfigMode=el.value;exportConfigQuery='';$('#export-config-search').value='';renderExportList();$('#export-config-list').scrollTop=0;return;}
  if(el.dataset.exportGroup!==undefined){
    if(configShareBusy)return;
    const [selected,names]=exportGroupMembers(el.dataset.exportGroup);
    for(const name of names){if(el.checked)selected.add(name);else selected.delete(name);}
    renderExportList(false);return;
  }
  if(el.dataset.exportRecording || el.dataset.exportTheme){
    const selection=el.dataset.exportRecording?selectedExportRecordings:selectedExportThemes;
    const name=el.dataset.exportRecording||el.dataset.exportTheme;
    if(el.checked)selection.add(name);else selection.delete(name);
    invalidateExportCode();renderExportList(false);return;
  }
  if(el.dataset.exportConfig){
    if(el.checked)selectedExportConfigs.add(el.dataset.exportConfig);else selectedExportConfigs.delete(el.dataset.exportConfig);
    invalidateExportCode();renderExportList(false);return;
  }
  if(el.id==='select-all-export-configs'){
    const recordingView=exportConfigMode==='@recordings',themeView=exportConfigMode==='@themes';
    const selection=recordingView?selectedExportRecordings:themeView?selectedExportThemes:selectedExportConfigs;
    const available=recordingView?exportRecordings:themeView?exportThemes:(exportCatalog||[]).map(config=>config.path);
    selection.clear();
    if(el.checked)for(const name of available)selection.add(name);
    if(exportConfigMode==='*'){
      for(const [selected,names] of [[selectedExportRecordings,exportRecordings],[selectedExportThemes,exportThemes]]){
        selected.clear();if(el.checked)for(const name of names)selected.add(name);
      }
    }
    invalidateExportCode();renderExportList(false);return;
  }
  if(['export-mode-list','export-safe-settings'].includes(el.id)){invalidateExportCode();return;}
  if(el.id==='custom-theme-base'){customThemeBase=el.value;customThemeDraft=[...themePresets[el.value]];renderThemes();return;}
  el.removeAttribute('aria-invalid');
  try {
    if (el.id === 'filter') { filter = el.value; syncIndexTiles(); }
    if (el.id === 'recorder-file') { recorderFile = el.value; return; }
    if (el.dataset.indexField) { indexDirty = true; indexRevision++; await saveIndex(); if (['unit','recording'].includes(el.dataset.indexField) && view === 'indexes') renderIndexes(); }
    if (el.dataset.settingField) {
      settingsDirty = true; settingsRevision++; await saveSettings(); updateFeedback();
    }
    if (el.dataset.modeField) {
      (draftMode ||= modeDraft())[el.dataset.modeField] = el.value;
      if (el.dataset.modeField === 'mode') { draftMode.map = state.catalog[el.value][0].name; draftMode.act = 'Act 1'; if(el.value==='Infinity Mansion')draftMode.difficulty='Normal'; if(el.value==='Events')draftMode.runs=9999; }
      if (['mode','map','act'].includes(el.dataset.modeField)) renderModes(false);
      modeDirty = true; savedSelection = null; modeRevision++; updateModeControls(); updateFeedback();
    }
    if (el.id === 'scope') { await window.flushEdits(); await request('config.scope',{scope:el.value}); render(); }
    if (el.id === 'config-choice') { await window.flushEdits(); await request('config.challenge',{map:el.value}); render(); }
    if (el.id === 'team') { await request('config.team',{team:el.value}); toast('Team saved'); }
  } catch(error) { el.setAttribute('aria-invalid','true'); if(keybind)keybindStatus(el.dataset.settingField,error.message||'Could Not Save',true); report(error); }
});
// Keep Tab in the current control instead of cycling through the macro UI.
document.addEventListener('keydown',e=>{if(e.key==='Tab')e.preventDefault();},true);
document.addEventListener('keydown', async e => {
  try {
    if(e.target.matches('.keybind-fields input')){
      e.preventDefault();
      if(e.repeat||['Control','Alt','Shift','Meta'].includes(e.key))return;
      const aliases={' ':'Space',ArrowUp:'Up',ArrowDown:'Down',ArrowLeft:'Left',ArrowRight:'Right',Escape:'Escape',Delete:'Delete',Insert:'Insert',PageUp:'PgUp',PageDown:'PgDn'};
      const numpad={NumpadDecimal:'NumpadDot',NumpadSubtract:'NumpadSub',NumpadMultiply:'NumpadMult',NumpadDivide:'NumpadDiv'};
      const physical=/^(?:Digit|Key)([0-9A-Z])$/.exec(e.code);
      const punctuation={Semicolon:';',Equal:'=',Comma:',',Minus:'-',Period:'.',Slash:'/',Backquote:'`',BracketLeft:'[',Backslash:'\\',BracketRight:']',Quote:"'"};
      const key=e.code.startsWith('Numpad')?(numpad[e.code]||e.code):(physical?.[1]||punctuation[e.code]||aliases[e.key]||e.key);
      e.target.value=[e.ctrlKey?'Ctrl':'',e.altKey?'Alt':'',e.shiftKey?'Shift':'',e.metaKey?'Win':'',key.length===1?key.toUpperCase():key].filter(Boolean).join('+');
      keybindStatus(e.target.dataset.settingField,'Click Away to Save');
      return;
    }
    if (e.target.closest('.contract-handle') && ['ArrowUp','ArrowDown'].includes(e.key)) {
      e.preventDefault();
      const card = e.target.closest('.contract-card'), parent = card.parentElement;
      const sibling = e.key === 'ArrowUp' ? card.previousElementSibling : card.nextElementSibling;
      if (sibling) { parent.insertBefore(card,e.key === 'ArrowUp' ? sibling : sibling.nextElementSibling); await persistPriorityOrder(); card.querySelector('button').focus(); }
    }
    if (['copy-source','copy-target'].includes(e.target.id) && e.key === 'Enter') { e.preventDefault(); $('#copy-confirm').click(); }
    if (e.key === 'Escape' && state?.picking) { await request('coordinates.cancel'); renderIndexes(); }
  } catch(error) { report(error); }
});
$('.game').addEventListener('contextmenu', async e => {
  if (!state?.picking) return;
  e.preventDefault();
  const r = $('.game').getBoundingClientRect();
  try { await request('coordinates.pick',{x:Math.min(state.mapWidth-1,Math.max(0,Math.round((e.clientX-r.left)/r.width*state.mapWidth))),y:Math.min(state.mapHeight-1,Math.max(0,Math.round((e.clientY-r.top)/r.height*state.mapHeight)))}); renderIndexes(); toast('Coordinates saved'); } catch(error) { report(error); }
});
$('.config .section-title').insertAdjacentHTML('beforeend','<button class="open-folder" data-open-folder="configs" title="Open Configs Folder" aria-label="Open Configs Folder"><i data-lucide="folder-open"></i></button>');
document.querySelector('header').addEventListener('mousedown', e => {
  if (e.button === 0 && !e.target.closest('button')) request('drag').catch(report);
});
let layoutSignature = '';
let layoutFramePending=false;
function scheduleLayout() {
  if(layoutFramePending)return;
  layoutFramePending=true;
  requestAnimationFrame(()=>{
    layoutFramePending=false;
    sendLayout();
  });
}
let renderedPageSignature = '';
function acknowledgeRenderedPage() {
  if(!Number.isInteger(state?.pageGeneration))return;
  const page=state.page,generation=state.pageGeneration,signature=page+'|'+generation;
  if(signature===renderedPageSignature)return;
  const firstRender=!renderedPageSignature;
  renderedPageSignature=signature;
  const acknowledge=()=>{
    if(state?.page!==page || state.pageGeneration!==generation || view!==page)return;
    sendLayout();
    request('page.rendered',{page,generation}).catch(error=>{
      if(renderedPageSignature===signature)renderedPageSignature='';
      report(error);
    });
  };
  // A hidden native window can throttle animation frames while waiting for this layout to show it.
  if(firstRender||document.hidden)queueMicrotask(acknowledge);
  else requestAnimationFrame(()=>requestAnimationFrame(acknowledge));
}
function sendLayout() {
  if (!state || ['settings','themes','export','guides'].includes(state.page)) return;
  const r = $('.game').getBoundingClientRect(), data = {x:Math.round(r.left),y:Math.round(r.top),width:Math.round(r.width),height:Math.round(r.height)};
  const signature = JSON.stringify(data);
  if (signature !== layoutSignature) { layoutSignature = signature; request('layout',data).catch(report); }
}
new ResizeObserver(scheduleLayout).observe($('.game'));
window.addEventListener('resize',scheduleLayout);
const helpTooltip = document.createElement('div');
helpTooltip.className = 'help-tooltip'; helpTooltip.id = 'setting-description'; helpTooltip.role = 'tooltip'; helpTooltip.hidden = true;
document.body.append(helpTooltip);
function showHelp(target) {
  helpTooltip.classList.toggle('page-help',target.dataset.helpPage === '1');
  if (target.dataset.helpPage === '1') {
    helpTooltip.innerHTML = target.dataset.help.split('\n').map(line => {
      const split = line.indexOf(': ');
      return `<p><strong>${esc(line.slice(0,split))}:</strong> ${esc(line.slice(split + 2))}</p>`;
    }).join('');
  } else helpTooltip.innerHTML = target.dataset.help.split('\n').map(line => {
    const label = /^([A-Za-z][^:\n]*:)(?=\s|$)/.exec(line);
    return label ? `<strong>${esc(label[0])}</strong>${esc(line.slice(label[0].length))}` : esc(line);
  }).join('\n');
  helpTooltip.hidden = false;
  target.setAttribute('aria-describedby',helpTooltip.id);
  const rect = target.getBoundingClientRect();
  helpTooltip.style.left = Math.max(8,Math.min(innerWidth - helpTooltip.offsetWidth - 8,rect.left)) + 'px';
  helpTooltip.style.top = Math.max(8,Math.min(innerHeight - helpTooltip.offsetHeight - 8,rect.bottom + 8)) + 'px';
}
document.addEventListener('pointerover',e=>{const help=e.target.closest('.setting-help'); if(help) showHelp(help);});
document.addEventListener('pointerout',e=>{if(e.target.closest('.setting-help') && !e.relatedTarget?.closest('.setting-help')) helpTooltip.hidden=true;});
function updateTypingFocus(){
  if(!state)return;
  const active=document.activeElement;
  request('hotkeys.typing',{active:!!active?.matches('input,textarea,select,[contenteditable="true"]')}).catch(report);
}
document.addEventListener('focusin',e=>{
  if(e.target.matches('.keybind-fields input')){
    e.target.dataset.keybindPrevious=keybindDrafts.get(e.target.dataset.settingField)??state.preferences[e.target.dataset.settingField]??e.target.value;
    e.target.dataset.keybindPreviousMessage=JSON.stringify(keybindMessages.get(e.target.dataset.settingField)||{text:'',error:false});
    e.target.value='';
    keybindStatus(e.target.dataset.settingField,'Press a Key');
  }
  updateTypingFocus();
});
document.addEventListener('focusout',e=>{
  const el=e.target;
  if(el.matches('.keybind-fields input')&&el.dataset.keybindPrevious!==undefined){
    const previous=el.dataset.keybindPrevious;
    const previousMessage=JSON.parse(el.dataset.keybindPreviousMessage);
    delete el.dataset.keybindPrevious;
    delete el.dataset.keybindPreviousMessage;
    if(!el.value.trim()||(el.value===previous&&!previousMessage.error)){
      el.value=previous;
      if(previousMessage.error)el.setAttribute('aria-invalid','true');else el.removeAttribute('aria-invalid');
      keybindStatus(el.dataset.settingField,previousMessage.text,previousMessage.error);
    }else el.dispatchEvent(new Event('change',{bubbles:true}));
  }
  queueMicrotask(updateTypingFocus);
});
document.addEventListener('focusin',e=>{if(e.target.matches('.setting-help')) showHelp(e.target);});
document.addEventListener('focusout',e=>{if(e.target.matches('.setting-help')) helpTooltip.hidden=true;});
document.addEventListener('click',e=>{if(e.target.closest('.setting-help')) {e.preventDefault();e.stopPropagation();}},true);
document.addEventListener('wheel', e => {
  if (e.ctrlKey || !e.deltaY) return;
  const select = e.target.closest('select[data-index-field],select#team');
  if (select && !select.disabled && (select.id === 'team' || ['slot', 'upgrade', 'priority'].includes(select.dataset.indexField))) {
    e.preventDefault();
    const next = Math.max(0, Math.min(select.options.length - 1, select.selectedIndex + Math.sign(e.deltaY)));
    if (next !== select.selectedIndex) {
      select.selectedIndex = next;
      select.dispatchEvent(new Event('change', {bubbles: true}));
    }
    return;
  }
  const grid = e.target.closest('.index-grid');
  if (grid) {
    e.preventDefault();
    grid.scrollTop += Math.sign(e.deltaY) * 48;
  }
}, {passive: false});
icons();
request('ready').catch(report);


$('#copy-category-dialog').addEventListener('close',()=>{request('ui.modal',{visible:false}).catch(report);});
