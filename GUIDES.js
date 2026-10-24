'use strict';
// Brand marks from Simple Icons (CC0).
const SETUP_DISCORD_ICON = '<svg aria-hidden="true" focusable="false" fill="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M20.317 4.3698a19.7913 19.7913 0 00-4.8851-1.5152.0741.0741 0 00-.0785.0371c-.211.3753-.4447.8648-.6083 1.2495-1.8447-.2762-3.68-.2762-5.4868 0-.1636-.3933-.4058-.8742-.6177-1.2495a.077.077 0 00-.0785-.037 19.7363 19.7363 0 00-4.8852 1.515.0699.0699 0 00-.0321.0277C.5334 9.0458-.319 13.5799.0992 18.0578a.0824.0824 0 00.0312.0561c2.0528 1.5076 4.0413 2.4228 5.9929 3.0294a.0777.0777 0 00.0842-.0276c.4616-.6304.8731-1.2952 1.226-1.9942a.076.076 0 00-.0416-.1057c-.6528-.2476-1.2743-.5495-1.8722-.8923a.077.077 0 01-.0076-.1277c.1258-.0943.2517-.1923.3718-.2914a.0743.0743 0 01.0776-.0105c3.9278 1.7933 8.18 1.7933 12.0614 0a.0739.0739 0 01.0785.0095c.1202.099.246.1981.3728.2924a.077.077 0 01-.0066.1276 12.2986 12.2986 0 01-1.873.8914.0766.0766 0 00-.0407.1067c.3604.698.7719 1.3628 1.225 1.9932a.076.076 0 00.0842.0286c1.961-.6067 3.9495-1.5219 6.0023-3.0294a.077.077 0 00.0313-.0552c.5004-5.177-.8382-9.6739-3.5485-13.6604a.061.061 0 00-.0312-.0286zM8.02 15.3312c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9555-2.4189 2.157-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.9555 2.4189-2.1569 2.4189zm7.9748 0c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9554-2.4189 2.1569-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.946 2.4189-2.1568 2.4189Z"/></svg>';
const SETUP_NVIDIA_ICON = '<svg aria-hidden="true" focusable="false" fill="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M8.948 8.798v-1.43a6.7 6.7 0 0 1 .424-.018c3.922-.124 6.493 3.374 6.493 3.374s-2.774 3.851-5.75 3.851c-.398 0-.787-.062-1.158-.185v-4.346c1.528.185 1.837.857 2.747 2.385l2.04-1.714s-1.492-1.952-4-1.952a6.016 6.016 0 0 0-.796.035m0-4.735v2.138l.424-.027c5.45-.185 9.01 4.47 9.01 4.47s-4.08 4.964-8.33 4.964c-.37 0-.733-.035-1.095-.097v1.325c.3.035.61.062.91.062 3.957 0 6.82-2.023 9.593-4.408.459.371 2.34 1.263 2.73 1.652-2.633 2.208-8.772 3.984-12.253 3.984-.335 0-.653-.018-.971-.053v1.864H24V4.063zm0 10.326v1.131c-3.657-.654-4.673-4.46-4.673-4.46s1.758-1.944 4.673-2.262v1.237H8.94c-1.528-.186-2.73 1.245-2.73 1.245s.68 2.412 2.739 3.11M2.456 10.9s2.164-3.197 6.5-3.533V6.201C4.153 6.59 0 10.653 0 10.653s2.35 6.802 8.948 7.42v-1.237c-4.84-.6-6.492-5.936-6.492-5.936z"/></svg>';
/* Microsoft Fluent UI System Icons: Desktop (MIT).
MIT License
Copyright (c) 2020 Microsoft Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
const SETUP_WINDOWS_DISPLAY_ICON = '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" focusable="false" xmlns="http://www.w3.org/2000/svg"><path d="M6.75 22.0004C6.33579 22.0004 6 21.6647 6 21.2504C6 20.8707 6.28215 20.557 6.64823 20.5073L6.75 20.5004L8.499 20.5V18.002L4.25 18.0023C3.05914 18.0023 2.08436 17.0771 2.00519 15.9063L2 15.7523V5.25C2 4.05914 2.92516 3.08436 4.09595 3.00519L4.25 3H19.7488C20.9397 3 21.9145 3.92516 21.9936 5.09595L21.9988 5.25V15.7523C21.9988 16.9431 21.0737 17.9179 19.9029 17.9971L19.7488 18.0023L15.499 18.002V20.5L17.25 20.5004C17.6642 20.5004 18 20.8362 18 21.2504C18 21.6301 17.7178 21.9439 17.3518 21.9936L17.25 22.0004H6.75ZM13.998 18.002H9.998L9.999 20.5004H13.999L13.998 18.002ZM19.7488 4.5H4.25C3.8703 4.5 3.55651 4.78215 3.50685 5.14823L3.5 5.25V15.7523C3.5 16.132 3.78215 16.4458 4.14823 16.4954L4.25 16.5023H19.7488C20.1285 16.5023 20.4423 16.2201 20.492 15.854L20.4988 15.7523V5.25C20.4988 4.8703 20.2167 4.55651 19.8506 4.50685L19.7488 4.5Z" fill="currentColor"/></svg>';
const SETUP_ROBLOX_ICON = '<svg aria-hidden="true" focusable="false" fill="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M18.926 23.998 0 18.892 5.075.002 24 5.108ZM15.348 10.09l-5.282-1.453-1.414 5.273 5.282 1.453z"/></svg>';
const SETUP_BRAND_ICONS = {discord:SETUP_DISCORD_ICON,nvidia:SETUP_NVIDIA_ICON,display:SETUP_WINDOWS_DISPLAY_ICON,roblox:SETUP_ROBLOX_ICON};
const SETUP_GUIDES = [
  {title:'Anime Adventures Settings',label:'Anime Adventures',icon:'gamepad-2',image:'Anime-Adventures-Settings.png',width:837,height:1878,
    steps:['Open **Anime Adventures** and click the **Settings** gear.','Scroll through the game settings and match the image.'],
    note:'Keep Disable Auto-Open Upgrade UI off and Show Upgrade UI on left on. Placement confirmation and upgrades require this layout.'},
  {title:'Roblox Settings',label:'Roblox',icon:'roblox',image:'Roblox-Settings.png',width:813,height:1066,
    steps:['Join **Anime Adventures** in Roblox.','Press **Esc**, then open **Settings** at the top of the Roblox menu.','Scroll through **Settings** and match the picture.','Press **Esc** to return to the game.'],
    },
  {title:'Windows Display Settings',label:'Windows Display',icon:'display',image:'Windows-Display.png',width:1268,height:845,
    steps:['Right-click an empty area of your **Windows desktop**.','Select **Display settings**, then select the monitor running Roblox.','Find **Brightness & color** and **Scale & layout**.','Match the settings in the picture.'],
    note:'The picture uses 1920 x 1080. Use a resolution your display supports; do not force an unsupported mode.'},
  {title:'Disable Discord Overlay',label:'Discord Overlay',icon:'discord',image:'Discord-Overlay.png',width:1294,height:377,
    steps:['Open the **Discord desktop app**.','Click the **gear** next to your username to open **User Settings**.','Scroll down the left menu and select **Game Overlay**.','Match the overlay switches in the picture.'],
    note:'This only disables the overlay. Discord webhooks and the macro bot can still be used.'},
  {title:'NVIDIA Desktop Color Settings',label:'NVIDIA Color',icon:'nvidia',image:'NVIDIA-Color.png',width:937,height:519,nvidia:true,
    steps:['Open **Start**, search **NVIDIA Control Panel**, and open it.','Expand **Display** and choose **Adjust desktop color settings**.','Select the monitor running Roblox.','Select **All channels**, match the picture, and click **Apply** if available.'],
    note:'NVIDIA only. Skip this page on AMD or Intel graphics. Some laptops do not expose these display controls.'},
  {title:'NVIDIA 3D Settings',label:'NVIDIA 3D',icon:'nvidia',image:'NVIDIA-3D.png',width:941,height:526,nvidia:true,
    steps:['Open **NVIDIA Control Panel**.','Expand **3D Settings** and choose **Manage 3D settings**.','Use **Program Settings** and select or add **Roblox** to limit changes to the game. The pictured **Global Settings** tab affects every program.','Match the picture, then click **Apply**. Leave settings not shown unchanged.'],
    note:'NVIDIA only. Skip this page on AMD or Intel graphics. Available options vary by driver and GPU.'}
];
let selectedSetupGuide = 0, setupPromptShown = false;
let startupGuideRequired=null,startupOverviewRequired=null;
function renderGuides() {
  const guide = SETUP_GUIDES[selectedSetupGuide];
  const reviewed = state.guidesRequired === false || state.guidesRequired === 0;
  $('#settings').innerHTML = `<div class="setup-guides"><div class="setup-guides-title"><div><h1>Settings Guide</h1><p>Apply these settings before starting the macro. Incorrect settings can prevent detection and clicks from working.</p></div><button id="guides-reviewed" class="primary" ${reviewed?'disabled':''}><i data-lucide="${reviewed?'check':'clipboard-check'}"></i>${reviewed?'Setup Reviewed':"I've Applied These Settings"}</button></div><div class="setup-guides-body"><nav class="setup-guide-nav" aria-label="Setup guide">${SETUP_GUIDES.map((item,i)=>`<button data-setup-guide="${i}" class="${i===selectedSetupGuide?'active':''}" aria-current="${i===selectedSetupGuide?'step':'false'}">${SETUP_BRAND_ICONS[item.icon]||`<i data-lucide="${item.icon}"></i>`}<span>${item.label}</span></button>`).join('')}</nav><section class="setup-guide-main" aria-labelledby="setup-guide-title"><div class="setup-guide-heading"><h2 id="setup-guide-title">${guide.title}</h2><span>${selectedSetupGuide+1} of ${SETUP_GUIDES.length}${guide.nvidia?' | NVIDIA only':''}</span></div><div class="setup-guide-detail"><div class="setup-guide-instructions"><h3>Where To Go</h3><ol>${guide.steps.map(step=>`<li>${esc(step).replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>')}</li>`).join('')}</ol>${guide.note?`<p class="setup-guide-note">${esc(guide.note)}</p>`:''}</div><figure class="setup-guide-picture"><div class="setup-guide-image"><img src="GuideImages/${guide.image}" width="${guide.width}" height="${guide.height}" alt="${guide.title} reference"></div><div class="setup-guide-image-tools"><button id="guide-enlarge" title="Enlarge screenshot"><i data-lucide="zoom-in"></i>Enlarge</button></div></figure></div><div class="setup-guide-controls"><button data-setup-guide="${selectedSetupGuide-1}" ${selectedSetupGuide===0?'disabled':''}><i data-lucide="chevron-left"></i>Back</button><button data-setup-guide="${selectedSetupGuide+1}" ${selectedSetupGuide===SETUP_GUIDES.length-1?'disabled':''}>Next<i data-lucide="chevron-right"></i></button></div></section></div></div>`;
  icons();
}
function promptForSetup() {
  if (!state) return;
  if(startupGuideRequired===null){
    startupGuideRequired=!!state.guidesRequired;
    startupOverviewRequired=!!state.overviewRequired;
  }
  if(startupGuideRequired && state.guidesRequired && !setupPromptShown){
    setupPromptShown = true;
    $('#setup-required-dialog').showModal();
  } else if(!state.guidesRequired) promptForOverview();
}

let overviewPromptShown=false, overviewStep=-1, overviewBusy=false;
function tutorialNavigationLocked(){return (view==='guides'&&!!state?.guidesRequired)||overviewStep>=0;}
function syncTutorialNavigation(){
  const locked=tutorialNavigationLocked();
  document.querySelectorAll('.rail [data-view]').forEach(button=>{
    if(button.disabled!==locked)button.disabled=locked;
    if(button.getAttribute('aria-disabled')!==String(locked))button.setAttribute('aria-disabled',String(locked));
  });
}
const OVERVIEW_STEPS=[
  {page:'main',title:'Main: Your Session',text:'Main shows Roblox, your current mode, and session results. Check the **Process Log** to see what the macro is doing.'},
  {page:'gamemodes',title:'Modes: Choose Your Match',target:'.mode-editor',text:'Choose the **Gamemode** and **Map**, then the available **Act**, **Difficulty**, or **Trait Mode**. **Runs** sets how many matches to do before moving to the next mode.',example:'Story | Planet Greenie | Act 1 | Normal | 1 Run'},
  {page:'gamemodes',title:'Add Mode: Build Your List',target:'#add-mode',text:'Click **Add Mode** to put your selection in the **Mode List**. Repeat to add more modes. The macro runs the list from top to bottom.'},
  {page:'gamemodes',title:'Edit: Change an Existing Mode',target:'.mode-row [data-mode], .mode-list-heading',text:'Click **Edit** on a mode card to load its options. Clicking the card itself only selects it; it does not open it for editing.'},
  {page:'gamemodes',title:'Save Changes: Finish Editing',target:'#save-selection',text:'After editing a mode, click **Save Changes** to keep your changes and finish editing. Unlike index changes, mode edits need this button.'},
  {page:'gamemodes',title:'Mode List: Reorder or Remove',target:'.mode-queue-tools',text:'Select a mode card, then use **Move Up/Down** to change its position. **Delete Mode** removes that card from the list, not its saved config.'},
  {page:'indexes',title:'Indexes: Your Action List',target:'.index-grid',text:'Indexes are actions for the selected config. They run in number order. Click a box to edit it. **Index changes save automatically**.'},
  {page:'indexes',title:'Index Name',field:'name',text:'Name the action so it is easy to find later.',example:'Index 1: Place C.E.O. 1\nIndex 2: C.E.O. 1 to MAX'},
  {page:'indexes',title:'Unit Slot/Action',field:'slot',text:'1-6 places a unit from your unit hotbar. Left/Right Click performs those mouse actions at the saved coordinates',example:'Slot 2 places the unit equipped in your second hotbar slot.'},
  {page:'indexes',title:'Upgrade: Set a Target',field:'upgrade',text:'**0** means no upgrades. A number sets the target upgrade level. **MAX** upgrades the unit to its maximum.',example:'Upgrade 3 means this index upgrades the unit until it reaches upgrade level 3.'},
  {page:'indexes',title:'Unit Priority',field:'priority',text:'Choose the unit\'s targeting priority: **First**, **Strongest**, **Closest**, **Last**, **Farthest**, or **Weakest**. This does not change index order.'},
  {page:'indexes',title:'On Wave: Wait For a Wave',field:'wave',text:'Waits until this wave or later before running the index. **0** means no wave wait.',example:'On Wave 5 waits until wave 5 or later.'},
  {page:'indexes',title:'Wait (ms): Add a Delay',field:'wait',text:'Adds a delay before the index action triggers. 1000ms = 1 second. 0 means no delay',example:'Wait 1000 = a 1-second delay before the index action. Wait 0 = no delay.'},
  {page:'indexes',title:'Recording: Replay Saved Inputs',field:'recording',text:'Choose a saved recording to play **instead of unit actions**. **None** uses normal actions. Wave and delay waits still apply.'},
  {page:'indexes',title:'Coordinates: Where To Act',target:'#pick',demo:'coordinates',text:'**X** is left/right and **Y** is up/down inside Roblox. Click **Select Coordinates**, then right-click a spot. Reuse its coordinates to upgrade the same unit.'},
  {page:'indexes',title:'Auto Ability',field:'autoAbility',text:'Turns on the unit\'s **auto ability** when its in-game toggle is available.'},
  {page:'indexes',title:'Index Tools: Reorder or Reset',target:'footer .actions',text:'**Move Up/Down** reorders indexes. **Reset Index** clears one index. **Copy Paste Tool** replaces its destination. **Reset Config** clears this config\'s indexes and team.'},
  {page:'recorder',title:'Recorder: Capture Your Inputs',text:'Click **Roblox** first. Press **Record/Stop** to begin recording your inputs. Press again to stop.'},
  {page:'recorder',title:'Recorder: Save, Then Test',text:'Enter a name and **Save Recording**. **Test/Stop Recording** starts or stops playback. Select the saved recording in an index to use it.'},
  {page:'detection',title:'Detection: Troubleshooting',target:'.detection-editor',text:'**OCR** reads text on the screen. Detection lets you capture, replace, and test reference images for supported checks. A configured image can replace OCR for that check when text recognition is unreliable.',caution:'**Caution: Advanced users only.** Change these references only to troubleshoot detection problems.'},
  {page:'themes',title:'Themes: Appearance Only',text:'Choose a preset or customize colors and a background. **Save Theme** saves a custom theme.'},
  {page:'settings',settings:'General',target:'[data-settings="General"]',title:'General: Servers & Startup',text:'Choose private or public server options, set up optional **Discord bot commands**, and control startup prompts. **Start Tutorial** reopens this overview. Changes save automatically.'},
  {page:'settings',settings:'Webhooks',target:'[data-settings="Webhooks"]',title:'Webhooks: Discord Updates',text:'Add a **Webhook URL** to send progress and results to Discord. Choose what messages include and whether they ping you.'},
  {page:'settings',settings:'Challenges',target:'[data-settings="Challenges"]',title:'Challenges: Automatic Runs',text:'Enable daily or half-hourly challenges. **First Mode** chooses what runs at startup. **Force Leave** interrupts your match for a challenge; off waits until the run finishes.'},
  {page:'settings',settings:'Event',target:'[data-settings="Event"]',title:'Event: Contract Order',text:'Drag the **grip handle** beside a contract to reorder it. Contracts higher in the list are preferred when the macro chooses a Hunter contract.'},
  {page:'settings',settings:'Delays',target:'[data-settings="Delays"]',title:'Delays: Wait Times',text:'Adjust waits for placement, menu clicks, movement, results, and screenshots. **1000 ms = 1 second.** Keep the defaults unless an action needs more time.'},
  {page:'settings',settings:'Keybinds',target:'[data-settings="Keybinds"]',title:'Keybinds: Keyboard Shortcuts',text:'Click a key box, press a key or shortcut such as **1**, **2**, or **Ctrl+1**, then click away to save. Leaving it empty keeps your previous key. **Restore Default Keybinds** resets the original shortcuts.'},
  {page:'main',title:'Ready To Start',text:'Configure your modes and indexes, then use **Start** to run. **Pause** pauses and **Close** exits. Find your keys in **Settings > Keybinds**.'}
];
function overviewText(text){return esc(text).replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>');}
function coordinateTutorialDemo(){
  return `<div class="coordinate-demo" role="img" aria-label="Example: click Select Coordinates, right-click a map position, then index 1 appears at X 456 and Y 312."><div class="coordinate-demo-toolbar"><span class="coordinate-demo-pick"><i data-lucide="crosshair"></i>Select Coordinates</span><span class="coordinate-demo-label">Example</span></div><div class="coordinate-demo-stage"><div class="coordinate-demo-map"><img src="GuideImages/Planet-Greenie-Overview.png" alt="" draggable="false"><span class="marker selected coordinate-demo-marker">1</span><span class="coordinate-demo-click">Right-click</span></div></div><div class="coordinate-demo-fields"><span>X <b class="coordinate-demo-value">456</b></span><span>Y <b class="coordinate-demo-value">312</b></span><span class="coordinate-demo-saved"><i data-lucide="check"></i>Selected</span></div><i data-lucide="mouse-pointer-2" class="coordinate-demo-cursor"></i></div>`;
}
function clearOverviewHighlight(){document.querySelectorAll('.overview-highlight,.overview-target').forEach(el=>el.classList.remove('overview-highlight','overview-target'));}
function positionOverviewDialog(){
  const dialog=$('#macro-overview-dialog');
  if(!dialog?.open)return;
  const game=$('.game')?.getBoundingClientRect();
  const covered=['settings','themes','guides'].includes(state?.page);
  // HTML dialogs cannot cover Roblox's native window cutout. Stay in the sidebar.
  const left=game&&!covered?Math.max(game.right+12,innerWidth-376):innerWidth-376;
  dialog.style.left=Math.max(12,left)+'px';dialog.style.right='16px';dialog.style.width='auto';
  const target=$('.overview-target')?.getBoundingClientRect();
  const top=target&&target.top>innerHeight/2;
  dialog.style.top=top?'64px':'auto';dialog.style.bottom=top?'auto':'16px';
}
window.addEventListener('resize',positionOverviewDialog);
function overviewDialog(){
  let dialog=$('#macro-overview-dialog');
  if(!dialog){
    dialog=document.createElement('dialog');dialog.id='macro-overview-dialog';
    dialog.setAttribute('aria-labelledby','macro-overview-title');
    dialog.addEventListener('cancel',event=>event.preventDefault());
    document.body.append(dialog);
  }
  return dialog;
}
function promptForOverview(){
  if(!startupOverviewRequired || !state?.overviewRequired || overviewPromptShown || (startupGuideRequired&&state.guidesRequired) || $('#setup-required-dialog').open)return;
  overviewPromptShown=true;
  const dialog=overviewDialog();
  dialog.innerHTML='<h2 id="macro-overview-title">Would You Like a Quick Tour?</h2><p>Get a basic overview of the macro and its main controls.</p><div class="overview-actions"><button id="overview-start" class="primary"><i data-lucide="presentation"></i>Start Tutorial</button><button id="overview-skip">No, Skip the Tutorial</button></div>';
  icons();dialog.showModal();positionOverviewDialog();
}
async function showOverviewStep(index){
  const step=OVERVIEW_STEPS[index];
  await window.flushEdits();
  if(step.page==='settings')settingsTab=step.settings||'General';
  if(state.page!==step.page)await request('navigate',{page:step.page});
  overviewStep=index;
  syncTutorialNavigation();
  clearOverviewHighlight();
  if(step.page==='indexes'){
    editorPage=step.editor||1;
    renderIndexes();
  }
  if(step.page==='settings')renderSettings();
  document.querySelector(`[data-view="${step.page}"]`)?.classList.add('overview-highlight');
  const control=step.field?document.querySelector(`[data-index-field="${step.field}"]`):step.target?step.target.split(',').map(selector=>document.querySelector(selector.trim())).find(Boolean):null;
  const target=control?.closest('label')||control;
  if(target){
    const scroll=target.closest('.editor-scroll');
    if(scroll){
      const bounds=scroll.getBoundingClientRect(),rect=target.getBoundingClientRect();
      if(rect.bottom>bounds.bottom)scroll.scrollTop+=rect.bottom-bounds.bottom+6;
      else if(rect.top<bounds.top)scroll.scrollTop-=bounds.top-rect.top+6;
    }
    target.classList.add('overview-target');
  }
  if(step.extraField){
    const extra=document.querySelector(`[data-index-field="${step.extraField}"]`);
    (extra?.closest('label')||extra)?.classList.add('overview-target');
  }
  const dialog=overviewDialog();
  dialog.innerHTML=`<span class="overview-count">${index+1} of ${OVERVIEW_STEPS.length}</span><h2 id="macro-overview-title">${esc(step.title)}</h2><p>${overviewText(step.text)}</p>${step.example?`<p class="overview-example">${overviewText(step.example)}</p>`:''}${step.items?`<ul class="overview-points">${step.items.map(item=>`<li><strong>${esc(item.label)}:</strong> ${overviewText(item.text)}</li>`).join('')}</ul>`:''}${step.caution?`<p class="overview-caution">${overviewText(step.caution)}</p>`:''}${step.demo==='coordinates'?coordinateTutorialDemo():''}<div class="overview-actions"><button id="overview-back" ${index===0?'disabled':''}><i data-lucide="chevron-left"></i>Back</button><button id="overview-next" class="primary ${index===OVERVIEW_STEPS.length-1?'overview-finish':''}">${index===OVERVIEW_STEPS.length-1?'<i data-lucide="check"></i>Finish Tutorial':'Next<i data-lucide="chevron-right"></i>'}</button>${index===OVERVIEW_STEPS.length-1?'':'<button id="overview-exit">Exit Tutorial</button>'}</div>`;
  icons();if(!dialog.open)dialog.showModal();positionOverviewDialog();
}
async function handleOverviewClick(button){
  if(!['overview-start','overview-skip','overview-back','overview-next','overview-exit','overview-replay'].includes(button.id))return false;
  if(overviewBusy)return true;
  overviewBusy=true;button.disabled=true;
  try{
    if(button.id==='overview-skip' || button.id==='overview-exit' || (button.id==='overview-next'&&overviewStep===OVERVIEW_STEPS.length-1)){
      await request('overview.reviewed');overviewDialog().close();overviewStep=-1;
      syncTutorialNavigation();
      clearOverviewHighlight();
      if(state.page==='settings')renderSettings();
    }else await showOverviewStep(button.id==='overview-back'?overviewStep-1:button.id==='overview-next'?overviewStep+1:0);
  }catch(error){report(error);}finally{overviewBusy=false;if(button.isConnected)button.disabled=false;}
  return true;
}
