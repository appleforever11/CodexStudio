  const workspaceUI = (() => {
    let controls = null, reading = null, navigation = null;
    const responseNodes = new Set();
    const variables = {
      sidebarOpacity: '--ds-ui-sidebar-opacity', sidebarDim: '--ds-ui-sidebar-dim', sidebarBlur: '--ds-ui-sidebar-blur',
      chatOpacity: '--ds-ui-chat-opacity', chatDim: '--ds-ui-chat-dim', chatBlur: '--ds-ui-chat-blur',
      rowSpacing: '--ds-ui-row-spacing', readingWidth: '--ds-ui-reading-width',
    };
    const focus = () => {
      const active = workspaceSession.focus ?? workspaceSettings.focusByDefault;
      document.documentElement.setAttribute('data-dream-reading', String(Boolean(active)));
      controls?.focus.setAttribute('aria-pressed', String(Boolean(active)));
      if (controls) controls.focus.textContent = active ? 'Exit reading' : 'Reading view';
    };
    const toggleFocus = () => { workspaceSession.focus = !(workspaceSession.focus ?? workspaceSettings.focusByDefault); focus(); };
    const groupResponses = () => {
      const desired = new Set();
      if (workspaceSettings.groupResponses) {
        const responseSelector = '[data-local-conversation-item-target-ids], [data-local-conversation-final-assistant], [data-message-author-role="assistant"]';
        // Current local turns have a user branch followed by a response branch.
        // Tag the existing response ancestor without reparenting React nodes.
        for (const user of document.querySelectorAll('.thread-scroll-container [data-local-conversation-user-anchor]')) {
          const turn = user.parentElement?.parentElement;
          if (!turn || turn.querySelectorAll('[data-local-conversation-user-anchor]').length !== 1) continue;
          for (const child of turn.children) {
            if (!child.contains(user) && child.querySelector(responseSelector)) desired.add(child);
          }
        }
        for (const assistant of document.querySelectorAll('.thread-scroll-container [data-message-author-role="assistant"]')) {
          if (![...desired].some(e => e.contains(assistant))) desired.add(assistant);
        }
      }
      for (const node of responseNodes) if (!desired.has(node)) node.removeAttribute('data-dream-response');
      responseNodes.clear();
      for (const node of desired) {
        if (!node.hasAttribute('data-dream-response')) node.setAttribute('data-dream-response', '');
        responseNodes.add(node);
      }
    };
    return {
      refresh() {
        if (!workspaceSettings.enabled) return;
        const root = document.documentElement;
        setAttribute(root, 'data-dream-workspace-ui', 'true');
        setAttribute(root, 'data-dream-wrap-titles', String(workspaceSettings.wrapTitles));
        setAttribute(root, 'data-dream-search-context', String(workspaceSettings.searchContext));
        for (const [name, variable] of Object.entries(variables)) {
          const unit = /Blur$|Spacing$|Width$/.test(name) ? 'px' : '';
          setStyleProperty(root, variable, `${workspaceSettings[name]}${unit}`);
        }
        if (!controls) {
          controls = createWorkspaceControls();
          controls.focus.addEventListener('click', toggleFocus);
          reading = createWorkspaceReading(controls);
          navigation = createWorkspaceNavigation(controls);
        }
        controls.mount(); focus(); groupResponses(); reading.refresh(); navigation.refresh();
      },
      dispose() {
        reading?.dispose(); navigation?.dispose();
        controls?.focus.removeEventListener('click', toggleFocus);
        controls?.dispose(); controls = null;
        for (const node of responseNodes) node.removeAttribute('data-dream-response');
        responseNodes.clear();
      },
    };
  })();
