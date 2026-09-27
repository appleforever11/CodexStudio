  // Direct ChatGPT enhancements. Native controls and React nodes stay in place.
  const directWorkspace = (() => {
    let host, shadow, outlineButton, panelButton, list, signature = '';
    let collapsed = previous?.directSession?.collapsed ?? false;
    const details = new Map(), outputActions = new Map();
    const attrs = new Set();
    const mark = (node, key, value = '') => { setAttribute(node, key, value); attrs.add(node); };
    const button = (text, action) => {
      const b = document.createElement('button'); b.type = 'button'; b.textContent = text;
      b.addEventListener('click', action); return b;
    };
    const panelState = () => {
      const panel=document.querySelector('[data-summary-panel-variant="summary"]');
      // Stretch only the native floating-summary wrapper chain, never the
      // conversation or another sidebar. Keep the native viewport insets.
      if(panel){
        const chain=[];let node=panel.parentElement;
        while(node && chain.length<5 && !node.style.getPropertyValue('--thread-floating-panel-full-width-progress')){
          chain.push(node);node=node.parentElement;
        }
        if(node?.style.getPropertyValue('--thread-floating-panel-full-width-progress')){
          for(const wrapper of chain)if(getComputedStyle(wrapper).display!=='contents')mark(wrapper,'data-dream-summary-fill');
        }
      }
      setAttribute(document.documentElement, 'data-dream-summary-collapsed', String(collapsed));
      if (panelButton) {
        panelButton.textContent = collapsed ? 'Outputs & sources' : 'Hide panel';
        panelButton.setAttribute('aria-expanded', String(!collapsed));
        panelButton.hidden = !document.querySelector('[data-summary-panel-variant="summary"]');
      }
      const state = window[STATE_KEY]; if (state) state.directSession = { collapsed };
    };
    const closeOutline=()=>{list?.hidePopover();if(list)list.hidden=true;outlineButton?.setAttribute('aria-expanded','false');};
    const mount = () => {
      if (!host) {
        host = document.createElement('span'); host.setAttribute('data-dream-direct-controls', '');
        shadow = host.attachShadow({mode:'open'});
        const style = document.createElement('style');
        style.textContent = `:host{display:inline-flex;position:relative;font:12px system-ui;color:var(--ds-text);-webkit-app-region:no-drag}
          button{font:inherit;color:inherit;background:transparent;border:0;border-radius:8px;padding:6px 9px;cursor:pointer}
          button:hover,button[aria-expanded=true]{background:rgb(var(--ds-text-rgb)/.1)}
          button:focus-visible{outline:2px solid var(--ds-accent);outline-offset:2px}
          [hidden]{display:none!important} nav{position:fixed;inset:48px 24px auto auto;margin:0;z-index:100;width:min(340px,calc(100vw - 48px));max-height:65vh;overflow:auto;padding:10px;border:1px solid #ffffff25;border-radius:16px;background:rgb(var(--ds-panel-rgb)/.94);backdrop-filter:blur(28px);box-shadow:0 12px 40px #0004}
          nav button{display:block;width:100%;text-align:left;white-space:normal;line-height:1.45;padding:9px}
          p{margin:8px;font-size:11px;opacity:.7} @media(max-width:900px){button{padding:6px 5px;font-size:11px}}`;
        list = document.createElement('nav');list.hidden = true;list.setAttribute('popover','manual');list.setAttribute('aria-label','Conversation outline');
        outlineButton = button('Outline', () => { if(!list.hidden){closeOutline();return;}list.hidden=false;list.showPopover();outlineButton.setAttribute('aria-expanded','true');list.querySelector('button')?.focus({preventScroll:true}); });
        outlineButton.setAttribute('aria-expanded','false');
        panelButton = button('Hide panel', () => {collapsed = !collapsed;panelState();});
        shadow.append(style,outlineButton,panelButton,list);
        shadow.addEventListener('keydown', event => {if(event.key==='Escape'){closeOutline();outlineButton.focus({preventScroll:true});}});
      }
      const slot = document.querySelector('[data-app-shell-header-toolbar]')?.lastElementChild;
      if(slot && host.parentElement!==slot)slot.prepend(host);
      panelState();
    };
    const refreshOutline = () => {
      const nodes = [...document.querySelectorAll('.thread-scroll-container [data-local-conversation-user-anchor], .thread-scroll-container [data-message-author-role="user"]')];
      const unique = nodes.filter(n=>!nodes.some(other=>other!==n && other.contains(n))).slice(0,200);
      const key = unique.map(n=>(n.getAttribute('data-content-search-unit-key')||'')+n.textContent).join('|');
      if(key===signature && list.childElementCount) return;
      signature=key;list.replaceChildren();
      const note=document.createElement('p');note.textContent=unique.length ? 'Your requests · loaded in this chat' : 'Requests appear here as the chat loads.';list.append(note);
      unique.forEach((node,index)=>{
        const title=node.textContent.replace(/^You said:\s*/,'').replace(/\d{1,2}:\d{2}\s*[AP]M$/,'').replace(/\s+/g,' ').trim().slice(0,150)||'Attached content';
        const item=button(`${index+1}. ${title}`,()=>{
          if(!node.isConnected)return;
          const thread=node.closest('.thread-scroll-container');
          // Navigation is user intent, so reading protection must yield.
          thread.dispatchEvent(new Event('pointerdown'));
          const delta=node.getBoundingClientRect().top-thread.getBoundingClientRect().top-20;
          thread.scrollTop+=delta;
          closeOutline();outlineButton.focus({preventScroll:true});
        });list.append(item);
      });
      outlineButton.hidden=!document.querySelector('.thread-scroll-container');
    };
    const refreshComposer = () => {
      for(const node of document.querySelectorAll('[data-ds-part="composer"]')) {
        const editor=node.querySelector('[contenteditable="true"],textarea');if(!editor)continue;
        const empty=!(editor.value??editor.textContent).trim() && !node.querySelector('[data-composer-attachments] :is(img,button)');
        mark(node,'data-dream-compact',String(empty));

      }
    };
    const refreshDetails = () => {
      for(const [node,entry] of details) if(!node.isConnected){entry.button.remove();details.delete(node);}
      for(const final of document.querySelectorAll('[data-local-conversation-final-assistant]')){
        const response=final.closest('[data-dream-response]');
        if(!response){
          mark(final,'data-dream-final-backing');
          for(const native of final.parentElement?.querySelectorAll('button[aria-expanded]')||[]){
            if(/^Worked for\b/.test(native.textContent.trim()))mark(native,'data-dream-native-work-details');
          }
          continue;
        }
        if(details.has(response))continue;
        const candidates=[...response.querySelectorAll('[data-local-conversation-item-target-ids], [data-content-search-unit-key]:has([data-markdown-text-style="assistant-message"])')]
          .filter(n=>!final.contains(n)&&!n.contains(final)&&!n.querySelector('[role="alert"],[role="dialog"],input,textarea,[aria-label*="Approve"],[aria-label*="Allow"]'));
        if(!candidates.length)continue;
        const b=button(`Work details · ${candidates.length}`,()=>{
          const expanded=b.getAttribute('aria-expanded')!=='true';b.setAttribute('aria-expanded',String(expanded));
          for(const n of candidates)mark(n,'data-dream-detail-hidden',String(!expanded));
        });
        b.setAttribute('data-dream-work-details','');b.setAttribute('aria-expanded','false');
        response.prepend(b);for(const n of candidates)mark(n,'data-dream-detail-hidden','true');
        details.set(response,{button:b});
      }
    };
    const refreshOutputs = () => {
      for(const [row,b] of outputActions)if(!row.isConnected){b.remove();outputActions.delete(row);}
      for(const section of document.querySelectorAll('[data-summary-panel-variant] section')){
        if(section.querySelector('header')?.textContent.trim()!=='Outputs')continue;
        mark(section,'data-dream-output-section');
        for(const row of section.querySelectorAll('[data-slot="thread-summary-panel-item-button"],[data-slot="thread-summary-panel-item"]')){
          const label=row.querySelector('[data-slot="thread-summary-panel-item-label"]');
          if(!label)continue;
          mark(row,'data-dream-output-card');
          // Native thumbnails and file icons are enlarged by CSS. The original
          // row remains the Open action; any native action menus remain accessible.
          const trigger=row.matches('button')?row:row.querySelector('[data-slot="thread-summary-panel-item-trigger"]');
          if(trigger)mark(trigger,'data-dream-output-open');
          const path=row.getAttribute('title');
          if(row.matches('button') && path?.startsWith('/') && typeof window.__dreamSkinRevealOutput==='function' && !outputActions.has(row)){
            const reveal=button('Reveal in Finder',()=>window.__dreamSkinRevealOutput(JSON.stringify({path:row.getAttribute('title')})));
            reveal.setAttribute('data-dream-output-reveal','');row.after(reveal);outputActions.set(row,reveal);
          }
        }
      }
    };
    const input = event => {if(workspaceSettings.enabled && event.target.closest?.('[data-ds-part="composer"]'))refreshComposer();};
    const ready=()=>{if(workspaceSettings.enabled)refreshOutputs();};
    const revealResult=event=>{
      for(const [row,b] of outputActions)if(row.getAttribute('title')===event.detail?.path){
        b.title=event.detail.ok?'Shown in Finder':'Could not reveal this file';
        b.setAttribute('aria-label',b.title);b.textContent=event.detail.ok?'Reveal again':'Retry reveal';
      }
    };
    document.addEventListener('dream-skin-reveal-result',revealResult);
    document.addEventListener('dream-skin-output-ready',ready);
    const outside=event=>{if(host && !event.composedPath().includes(host)){closeOutline();}};
    document.addEventListener('pointerdown',outside);
    document.addEventListener('input',input);
    return {
      refresh(){if(!workspaceSettings.enabled)return;mount();refreshOutline();refreshComposer();refreshDetails();refreshOutputs();},
      dispose(){
        document.removeEventListener('dream-skin-reveal-result',revealResult);
        document.removeEventListener('dream-skin-output-ready',ready);
        document.removeEventListener('pointerdown',outside);
        document.removeEventListener('input',input);host?.remove();
        for(const b of outputActions.values())b.remove();outputActions.clear();
        for(const entry of details.values())entry.button.remove();
        for(const node of attrs)for(const attr of [...node.attributes])if(/^data-dream-(summary-fill|compact|options|secondary-control|detail-hidden|native-work-details|final-backing|output-)/.test(attr.name))node.removeAttribute(attr.name);
        details.clear();attrs.clear();
        document.documentElement.removeAttribute('data-dream-summary-collapsed');
      }
    };
  })();
