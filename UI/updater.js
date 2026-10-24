'use strict';
function setMacroVersion(version){
 const title="Bayzo's AA Macro v"+String(version).replace(/^v/i,'');
 document.title=title;document.querySelector('.brand strong').textContent=title;
}
let updateAnswerTimer;
function resetUpdate(){
 clearTimeout(updateAnswerTimer);
 document.querySelector('#update-dialog').dataset.loading='false';
 document.querySelector('#update-no').disabled=false;
 const yes=document.querySelector('#update-yes');yes.disabled=false;
 yes.innerHTML='<i data-lucide="download"></i>Yes';window.lucide?.createIcons();
}
function positionUpdate(){
 const dialog=document.querySelector('#update-dialog');if(!dialog.open)return;
 const panel=document.querySelector('#panel').getBoundingClientRect();
 const width=Math.min(370,Math.max(280,panel.width-24),innerWidth-24);
 dialog.style.width=width+'px';dialog.style.left=Math.max(12,Math.min(panel.left+12,innerWidth-width-12))+'px';
 dialog.style.top=Math.max(12,Math.min(panel.top+12,innerHeight-dialog.offsetHeight-12))+'px';
}
function showUpdate(data){
 resetUpdate();setMacroVersion(data.current);
 const version=value=>'v'+String(value).replace(/^v/i,'');
 document.querySelector('#update-current').textContent=version(data.current);
 document.querySelector('#update-new').textContent=version(data.tag);
 document.querySelector('#update-question').textContent=`Would you like to update to version ${version(data.tag)}?`;
 const notes=document.querySelector('#update-notes');notes.replaceChildren();let list=null;
 for(const line of (data.notes||'No update notes provided.').split(/\r?\n/)){
  if(!line.trim()){list=null;continue;}
  const bullet=line.match(/^\s*[-*]\s+(.+)$/),heading=line.match(/^#{1,6}\s+(.+)$/);let element;
  if(bullet){if(!list){list=document.createElement('ul');notes.append(list);}element=document.createElement('li');element.textContent=bullet[1];list.append(element);}
  else{list=null;element=document.createElement(heading?'h4':'p');element.textContent=heading?heading[1]:line;notes.append(element);}
 }
 const dialog=document.querySelector('#update-dialog');if(!dialog.open)dialog.showModal();positionUpdate();
 window.lucide?.createIcons();document.querySelector('#update-no').focus();
 if(data.autoAnswer)setTimeout(()=>answerUpdate(data.autoAnswer==='Yes'),600);
}
function answerUpdate(accept){
 const dialog=document.querySelector('#update-dialog');if(!dialog.open||dialog.dataset.loading==='true')return;
 if(!accept){dialog.close();window.chrome?.webview?.postMessage({command:'updateAnswer',accept:false});return;}
 dialog.dataset.loading='true';document.querySelector('#update-no').disabled=true;
 const yes=document.querySelector('#update-yes');yes.disabled=true;
 yes.innerHTML='<i data-lucide="loader-circle" class="update-spinner"></i>Updating...';
 document.querySelector('#update-question').textContent='Downloading update...';window.lucide?.createIcons();
 updateAnswerTimer=setTimeout(async()=>{
  try { await window.flushEdits(); window.chrome?.webview?.postMessage({command:'updateAnswer',accept:true}); }
  catch(error){resetUpdate();document.querySelector('#update-question').textContent='Save failed. Your changes were not discarded. '+error.message;}
 },600);
}
document.querySelector('#update-yes').onclick=()=>answerUpdate(true);
document.querySelector('#update-no').onclick=()=>answerUpdate(false);
document.querySelector('#update-dialog').addEventListener('cancel',event=>{event.preventDefault();answerUpdate(false);});
window.addEventListener('resize',positionUpdate);
window.chrome?.webview?.addEventListener('message',event=>{
 if(event.data.state?.version)setMacroVersion(event.data.state.version);
 if(event.data.update)showUpdate(event.data.update);
 if(event.data.updateFailed){resetUpdate();document.querySelector('#update-question').textContent='Update failed. Try again or choose No.';}
});

