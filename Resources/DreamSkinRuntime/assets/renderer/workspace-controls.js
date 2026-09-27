  const workspaceSettings = THEME.workspaceUI || { enabled: false };
  const workspaceSession = previous?.workspaceSession || { focus: null, search: null, statuses: new Map() };
  const createWorkspaceControls = () => {
    const host = document.createElement('span');
    host.setAttribute('data-dream-workspace-controls', '');
    host.style.cssText = 'display:inline-flex;flex-shrink:0;pointer-events:auto;-webkit-app-region:no-drag';
    const shadow = host.attachShadow({ mode: 'open' });
    const style = document.createElement('style');
    style.textContent = `
      :host{font:12px -apple-system,system-ui;color:var(--ds-text,#eee)}
      button{font:inherit;color:inherit;background:transparent;border:1px solid transparent;
        border-radius:9px;padding:6px 9px;cursor:pointer;white-space:nowrap}
      button:hover,button[aria-pressed=true]{background:rgb(var(--ds-text-rgb,255 255 255)/.09)}
      button:focus-visible{outline:2px solid var(--ds-accent,#e3a955);outline-offset:2px}
      [hidden]{display:none!important} @media(max-width:700px){button{padding-inline:5px;font-size:11px}}
    `;
    const focus = document.createElement('button');
    focus.type = 'button'; focus.textContent = 'Reading view';
    focus.title = 'Reduce wallpaper detail and hide the summary panel';
    focus.setAttribute('aria-label', 'Toggle focused reading view');
    const back = document.createElement('button');
    back.type = 'button'; back.textContent = 'Back to results'; back.hidden = true;
    shadow.append(style, back, focus);
    const latestHost = document.createElement('div');
    latestHost.setAttribute('data-dream-latest-control', '');
    latestHost.style.cssText = 'position:fixed;z-index:45;pointer-events:none;transform:translateX(-50%);-webkit-app-region:no-drag';
    const latestShadow = latestHost.attachShadow({ mode: 'open' });
    const latestStyle = style.cloneNode(true);
    latestStyle.textContent += `button{pointer-events:auto;background:rgb(var(--ds-panel-rgb,42 29 23)/.94);
      border-color:rgb(var(--ds-text-rgb,255 255 255)/.18);box-shadow:0 4px 18px #0003;border-radius:20px;padding:8px 14px}`;
    const latest = document.createElement('button');
    latest.type = 'button'; latest.textContent = '↓ Return to latest';
    latest.setAttribute('aria-label', 'Return to latest message');
    latestShadow.append(latestStyle, latest);
    latestHost.hidden = true;
    return {
      host, focus, back, latest, latestHost,
      mount() {
        const toolbar = document.querySelector('[data-app-shell-header-toolbar]');
        const slot = toolbar?.lastElementChild;
        if (slot && host.parentElement !== slot) slot.prepend(host);
        if (!latestHost.isConnected && document.body) document.body.append(latestHost);
      },
      dispose() { host.remove(); latestHost.remove(); },
    };
  };
