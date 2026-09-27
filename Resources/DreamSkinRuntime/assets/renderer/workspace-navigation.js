  const createWorkspaceNavigation = (controls) => {
    let retry = null, disposed = false, lastHighlight = '';
    const querySelector = 'input[placeholder="Search chats"]';
    const currentRoute = () => document.querySelector('[data-app-action-sidebar-thread-selected="true"]')
      ?.getAttribute('data-app-action-sidebar-thread-id') || '';
    const captureSearch = (event) => {
      if (!workspaceSettings.searchContext) return;
      const input = document.querySelector(querySelector);
      const item = event.target.closest?.('[cmdk-item], [role="option"]');
      const enter = event.type === 'keydown' && event.key === 'Enter' && event.target === input;
      if (!input || (!item && !enter) || !input.value.trim()) return;
      workspaceSession.search = { query: input.value.trim().slice(0, 160), origin: currentRoute(), target: null, at: Date.now() };
      lastHighlight = '';
    };
    const back = () => {
      const search = workspaceSession.search;
      if (!search) return;
      document.querySelector('aside button[aria-label="Search"]')?.click();
      let tries = 0;
      const fill = () => {
        if (disposed) return;
        const input = document.querySelector(querySelector);
        if (!input && ++tries < 20) { retry = setTimeout(fill, 100); return; }
        if (!input) return;
        const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')?.set;
        setter?.call(input, search.query);
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.focus();
      };
      fill();
    };
    const highlight = () => {
      const search = workspaceSession.search;
      const route = currentRoute();
      if (search && !search.target && route && (route !== search.origin || !document.querySelector(querySelector))) search.target = route;
      const active = workspaceSettings.searchContext && search && Date.now() - search.at < 30 * 60 * 1000
        && search.target === route && !document.querySelector(querySelector);
      controls.back.hidden = !active;
      if (!active) { CSS.highlights?.delete('dream-skin-search'); lastHighlight = ''; return; }
      const thread = document.querySelector('.thread-scroll-container');
      if (!thread || !CSS.highlights || typeof Highlight !== 'function') return;
      const signature = `${route}:${search.query}:${thread.textContent.length}`;
      if (signature === lastHighlight) return;
      lastHighlight = signature;
      const query = search.query.toLocaleLowerCase();
      const ranges = [];
      const walker = document.createTreeWalker(thread, NodeFilter.SHOW_TEXT);
      let node, visited = 0;
      while ((node = walker.nextNode()) && visited++ < 5000 && ranges.length < 80) {
        if (node.parentElement.closest('button,textarea,input,[contenteditable],script,style,[data-dream-workspace-controls]')) continue;
        const content = node.textContent.toLocaleLowerCase();
        let start = content.indexOf(query);
        while (start >= 0 && ranges.length < 80) {
          const range = new Range(); range.setStart(node, start); range.setEnd(node, start + query.length);
          ranges.push(range); start = content.indexOf(query, start + query.length);
        }
      }
      CSS.highlights.set('dream-skin-search', new Highlight(...ranges));
      // Native search owns navigation. Highlight loaded matches without
      // moving the viewport away from its selected result.
    };
    const statuses = () => {
      for (const row of document.querySelectorAll('[data-app-action-sidebar-thread-row]')) {
        const id = row.getAttribute('data-app-action-sidebar-thread-id');
        const active = row.getAttribute('data-app-action-sidebar-thread-active') === 'true';
        const nativeLabels = [...row.querySelectorAll('[aria-label]')].map(e => e.getAttribute('aria-label')).join(' ');
        const attention = /needs (?:input|attention)|awaiting approval|approval required/i.test(nativeLabels);
        const completed = /\b(?:completed|done)\b/i.test(nativeLabels);
        const status = attention ? 'attention' : active ? 'working' : completed ? 'done' : null;
        if (id && status) workspaceSession.statuses.set(id, status);
        while (workspaceSession.statuses.size > 200) workspaceSession.statuses.delete(workspaceSession.statuses.keys().next().value);
        let badge = row.querySelector('[data-dream-thread-status]');
        if (!status) { badge?.remove(); continue; }
        if (!badge) {
          const owner = row.querySelector('[data-thread-title-trigger]');
          if (!owner) continue;
          badge = document.createElement('span'); owner.append(badge);
        }
        const text = status === 'working' ? 'Working' : status === 'attention' ? 'Needs input' : 'Done';
        if (badge.textContent !== text) badge.textContent = text;
        if (badge.getAttribute('data-dream-thread-status') !== status) badge.setAttribute('data-dream-thread-status', status);
      }
    };
    const dates = () => {
      if (!workspaceSettings.searchContext) return;
      for (const item of document.querySelectorAll('[cmdk-item]')) {
        const time = item.querySelector('time[datetime]');
        if (!time || item.querySelector('[data-dream-search-date]')) continue;
        const date = new Date(time.dateTime);
        if (!Number.isFinite(date.getTime())) continue;
        const label = document.createElement('span'); label.setAttribute('data-dream-search-date', '');
        label.textContent = date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
        item.append(label);
      }
    };
    document.addEventListener('click', captureSearch, true);
    document.addEventListener('keydown', captureSearch, true);
    controls.back.addEventListener('click', back);
    return {
      refresh() { statuses(); dates(); highlight(); },
      dispose() {
        disposed = true; clearTimeout(retry);
        document.removeEventListener('click', captureSearch, true);
        document.removeEventListener('keydown', captureSearch, true);
        controls.back.removeEventListener('click', back);
        document.querySelectorAll('[data-dream-thread-status],[data-dream-search-date]').forEach(e => e.remove());
        CSS.highlights?.delete('dream-skin-search');
      },
    };
  };
