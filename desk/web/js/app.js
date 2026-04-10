var App = {
  servers: [],
  oauthProviders: [],
  editing: null,

  init: function() {
    var url = window.location.origin + '/mcp-proxy/mcp';
    document.getElementById('agg-url').textContent = url;
    this.bindEvents();
    this.loadAll();
  },

  loadAll: function() {
    var self = this;
    Promise.all([
      McpProxyAPI.getServers(),
      OAuthAPI.getProviders().catch(function() { return { providers: [] }; })
    ]).then(function(results) {
      self.ship = results[0].ship || '';
      self.servers = results[0].servers || [];
      self.oauthProviders = results[1].providers || [];
      self.render();
      self.renderOAuth();
      self.updateEndpoint();
      self.populateOAuthSelects();
    });
  },

  updateEndpoint: function() {
    var url = window.location.origin + '/mcp-proxy/mcp';
    var cookieEl = document.getElementById('agg-cookie');
    var exampleEl = document.getElementById('endpoint-example');
    var ship = this.ship || '';
    var prefix = 'urbauth-' + ship + '=';
    var cookie = document.cookie.split(';').map(function(c) { return c.trim(); }).find(function(c) { return c.indexOf(prefix) === 0; }) || prefix + '...';
    cookieEl.textContent = 'Cookie: ' + cookie;
    exampleEl.textContent = 'claude mcp add --transport http mcp-proxy ' + url + ' --header "Cookie: ' + cookie + '"';
  },

  populateOAuthSelects: function() {
    var selects = document.querySelectorAll('.oauth-select');
    for (var i = 0; i < selects.length; i++) {
      var sel = selects[i];
      var val = sel.value;
      sel.innerHTML = '<option value="">None</option>';
      for (var j = 0; j < this.oauthProviders.length; j++) {
        var p = this.oauthProviders[j];
        var opt = document.createElement('option');
        opt.value = p.id;
        opt.textContent = p.id + (p.hasGrant ? ' (connected)' : '');
        sel.appendChild(opt);
      }
      sel.value = val;
    }
  },

  bindEvents: function() {
    var self = this;
    document.getElementById('add-form').addEventListener('submit', function(e) {
      e.preventDefault();
      var form = e.target;
      var id = form.elements.id.value.trim().toLowerCase().replace(/[^a-z0-9-]/g, '').replace(/^-+/, '').replace(/-+$/, '');
      var name = form.elements.name.value.trim();
      var url = form.elements.url.value.trim();
      var headers = self.getHeadersFromForm('add');
      var mode = form.elements.mode.value;
      var oauthProv = form.elements['oauth-provider'].value || null;
      var schemaUrl = form.elements['schema-url'] ? form.elements['schema-url'].value.trim() : '';
      if (!id || !name || (mode !== 'openapi' && !url)) return;
      McpProxyAPI.addServer(id, name, url, headers, {mode: mode, oauthProvider: oauthProv, schemaUrl: schemaUrl || null}).then(function() {
        form.reset();
        document.getElementById('add-schema-row').style.display = 'none';
        var rows = document.querySelectorAll('#add-headers .header-row');
        for (var i = 0; i < rows.length; i++) rows[i].remove();
        self.loadAll();
        self.toast('Server added');
      }).catch(function(e) { alert('Failed: ' + e.message); });
    });

    document.getElementById('oauth-add-form').addEventListener('submit', function(e) {
      e.preventDefault();
      var f = e.target;
      var data = {
        action: 'add-provider',
        id: f.elements['id'].value.trim().toLowerCase(),
        'auth-url': f.elements['auth-url'].value.trim(),
        'token-url': f.elements['token-url'].value.trim(),
        'revoke-url': f.elements['revoke-url'].value.trim() || null,
        'client-id': f.elements['client-id'].value.trim(),
        'client-secret': f.elements['client-secret'].value.trim(),
        'redirect-uri': f.elements['redirect-uri'].value.trim(),
        scopes: f.elements['scopes'].value.trim()
      };
      OAuthAPI.addProvider(data).then(function() {
        f.reset();
        self.loadAll();
        self.toast('Provider added');
      }).catch(function(e) { alert('Failed: ' + e.message); });
    });
  },

  getHeadersFromForm: function(prefix) {
    var container = document.getElementById(prefix + '-headers');
    if (!container) return [];
    var rows = container.querySelectorAll('.header-row');
    var headers = [];
    for (var i = 0; i < rows.length; i++) {
      var key = rows[i].querySelector('.header-key').value.trim();
      var value = rows[i].querySelector('.header-value').value.trim();
      if (key && value) headers.push({ key: key, value: value });
    }
    return headers;
  },

  addHeaderRow: function(container, key, value) {
    var row = document.createElement('div');
    row.className = 'header-row';
    var k = document.createElement('input');
    k.type = 'text'; k.className = 'header-key'; k.placeholder = 'Header name'; k.value = key || '';
    var v = document.createElement('input');
    v.type = 'text'; v.className = 'header-value'; v.placeholder = 'Header value'; v.value = value || '';
    var btn = document.createElement('button');
    btn.type = 'button'; btn.textContent = '\u00d7';
    btn.addEventListener('click', function() { row.remove(); });
    row.appendChild(k); row.appendChild(v); row.appendChild(btn);
    container.appendChild(row);
  },

  toggleSchemaUrl: function(prefix) {
    var mode = document.getElementById(prefix + '-mode').value;
    var row = document.getElementById(prefix + '-schema-row');
    var hint = document.getElementById(prefix + '-url-hint');
    var urlInput = document.getElementById(prefix + '-url');
    if (row) row.style.display = mode === 'openapi' ? '' : 'none';
    if (hint) hint.textContent = mode === 'openapi' ? 'API base URL (optional - derived from spec if empty)' : 'Upstream MCP server endpoint';
    if (urlInput) urlInput.required = mode !== 'openapi';
  },

  editServer: function(id) { this.editing = id; this.render(); this.populateOAuthSelects(); },
  cancelEdit: function() { this.editing = null; this.render(); },

  saveServer: function(id) {
    var self = this;
    var card = document.getElementById('edit-' + id);
    var name = card.querySelector('.edit-name').value.trim();
    var url = card.querySelector('.edit-url').value.trim();
    var headers = this.getHeadersFromForm('edit-h-' + id);
    var oauthProv = card.querySelector('.edit-oauth').value || null;
    var mode = card.querySelector('.edit-mode').value;
    var schemaInput = card.querySelector('.edit-schema-url');
    var schemaUrl = schemaInput ? schemaInput.value.trim() : '';
    var s = this.servers.find(function(x) { return x.id === id; });
    if (!name || !url) return;
    McpProxyAPI.updateServer(id, name, url, headers, s ? s.enabled : true, {mode: mode, oauthProvider: oauthProv, schemaUrl: schemaUrl || null}).then(function() {
      self.editing = null; self.loadAll(); self.toast('Server updated');
    }).catch(function(e) { alert('Failed: ' + e.message); });
  },

  refreshSpec: function(id) {
    McpProxyAPI.refreshSpec(id).then(function() {
      App.toast('Fetching spec...');
      setTimeout(function() { App.loadAll(); }, 3000);
    }).catch(function(e) { alert('Failed: ' + e.message); });
  },

  showTools: function(id) {
    var self = this;
    McpProxyAPI.getTools(id).then(function(data) {
      var tools = data.tools || [];
      var s = self.servers.find(function(x) { return x.id === id; });
      var filter = s && s.toolFilter ? s.toolFilter : null;
      var blockedSet = new Set(filter && filter.mode === 'block' ? filter.tools : []);
      var allowedSet = new Set(filter && filter.mode === 'allow' ? filter.tools : []);
      var isAllowMode = filter && filter.mode === 'allow';

      var html = '<div class="tool-list-panel" id="tools-' + id + '">';
      html += '<div class="tool-list-header"><span>' + tools.length + ' tools';
      if (filter) html += ' <span class="badge proxy-badge">' + filter.mode + ' filter</span>';
      html += '</span><span>' +
        '<button class="secondary" onclick="App.setAllTools(\'' + id + '\',true)">All</button> ' +
        '<button class="secondary" onclick="App.setAllTools(\'' + id + '\',false)">None</button> ' +
        '<button class="secondary" onclick="App.hideTools(\'' + id + '\')">Close</button>' +
        '</span></div>';
      html += '<div class="tool-list-items">';
      for (var i = 0; i < tools.length; i++) {
        var t = tools[i];
        var isBlocked = isAllowMode ? !allowedSet.has(t.name) : blockedSet.has(t.name);
        html += '<div class="tool-item ' + (isBlocked ? 'blocked' : '') + '">' +
          '<label><input type="checkbox" ' + (isBlocked ? '' : 'checked') +
          ' onchange="App.toggleTool(\'' + id + '\',\'' + self.esc(t.name) + '\',this.checked)">' +
          '<span class="tool-name">' + self.esc(t.name) + '</span></label>' +
          '<span class="tool-desc">' + self.esc((t.description || '').substring(0, 80)) + '</span></div>';
      }
      html += '</div></div>';

      var container = document.getElementById('server-tools-' + id);
      if (container) container.innerHTML = html;
    }).catch(function(e) { alert('Failed to load tools: ' + e.message); });
  },

  setAllTools: function(id, enabled) {
    var self = this;
    if (enabled) {
      McpProxyAPI.clearToolFilter(id).then(function() {
        self.loadAll();
        self.showTools(id);
      });
    } else {
      // block all: get tool list, block everything
      McpProxyAPI.getTools(id).then(function(data) {
        var tools = (data.tools || []).map(function(t) { return t.name; });
        McpProxyAPI.setToolFilter(id, 'block', tools).then(function() {
          self.loadAll();
          self.showTools(id);
        });
      });
    }
  },

  hideTools: function(id) {
    var container = document.getElementById('server-tools-' + id);
    if (container) container.innerHTML = '';
  },

  toggleTool: function(serverId, toolName, enabled) {
    var self = this;
    var s = this.servers.find(function(x) { return x.id === serverId; });
    var filter = s && s.toolFilter ? s.toolFilter : { mode: 'block', tools: [] };
    var toolSet = new Set(filter.tools || []);

    if (filter.mode === 'block') {
      if (enabled) toolSet.delete(toolName); else toolSet.add(toolName);
    } else {
      if (enabled) toolSet.add(toolName); else toolSet.delete(toolName);
    }

    var tools = Array.from(toolSet);
    if (tools.length === 0) {
      McpProxyAPI.clearToolFilter(serverId).then(function() { self.loadAll(); });
    } else {
      McpProxyAPI.setToolFilter(serverId, filter.mode, tools).then(function() { self.loadAll(); });
    }
  },

  toggleServer: function(id) {
    McpProxyAPI.toggleServer(id).then(function() { App.loadAll(); }).catch(function(e) { alert('Failed: ' + e.message); });
  },

  removeServer: function(id) {
    if (!confirm('Remove this server?')) return;
    McpProxyAPI.removeServer(id).then(function() { App.loadAll(); App.toast('Server removed'); }).catch(function(e) { alert('Failed: ' + e.message); });
  },

  connectProvider: function(id) {
    OAuthAPI.connect(id).then(function(data) {
      if (data && data.url) {
        window.open(data.url, '_blank');
        App.toast('Authorize in the new tab, then refresh');
      }
    }).catch(function(e) { alert('Connect failed: ' + e.message); });
  },

  disconnectProvider: function(id) {
    OAuthAPI.disconnect(id).then(function() { App.loadAll(); App.toast('Disconnected'); }).catch(function(e) { alert('Failed: ' + e.message); });
  },

  removeProvider: function(id) {
    if (!confirm('Remove this provider?')) return;
    OAuthAPI.removeProvider(id).then(function() { App.loadAll(); App.toast('Provider removed'); }).catch(function(e) { alert('Failed: ' + e.message); });
  },

  copyUrl: function(text) {
    if (navigator.clipboard) { navigator.clipboard.writeText(text); this.toast('Copied'); }
  },

  toast: function(msg) {
    var el = document.getElementById('toast');
    if (!el) { el = document.createElement('div'); el.id = 'toast'; el.className = 'toast'; document.body.appendChild(el); }
    el.textContent = msg; el.classList.add('show');
    setTimeout(function() { el.classList.remove('show'); }, 2000);
  },

  renderEditCard: function(s) {
    var isOpenapi = s.mode === 'openapi';
    var headersHtml = '<div id="edit-h-' + s.id + '-headers">';
    if (s.headers) {
      for (var j = 0; j < s.headers.length; j++) {
        headersHtml += '<div class="header-row"><input type="text" class="header-key" value="' + this.esc(s.headers[j].key) + '"><input type="text" class="header-value" value="' + this.esc(s.headers[j].value) + '"><button type="button" onclick="this.parentElement.remove()">\u00d7</button></div>';
      }
    }
    headersHtml += '</div>';
    return '<div class="server-card editing" id="edit-' + s.id + '">' +
      '<div class="form-row"><label>Name<input type="text" class="edit-name" value="' + this.esc(s.name) + '"></label>' +
      '<label>Mode<select class="edit-mode" onchange="App.toggleSchemaUrl(\'edit-' + s.id + '\')" id="edit-' + s.id + '-mode">' +
        '<option value="proxy"' + (isOpenapi ? '' : ' selected') + '>Proxy</option>' +
        '<option value="openapi"' + (isOpenapi ? ' selected' : '') + '>OpenAPI</option></select></label></div>' +
      '<div class="form-row"><label>URL<input type="url" class="edit-url" value="' + this.esc(s.url) + '"></label>' +
      '<label>OAuth<select class="edit-oauth oauth-select"><option value="">None</option></select></label></div>' +
      '<div class="form-row" id="edit-' + s.id + '-schema-row" style="' + (isOpenapi ? '' : 'display:none') + '">' +
        '<label>Schema URL<input type="url" class="edit-schema-url" value="' + this.esc(s.schemaUrl || '') + '"></label></div>' +
      '<span class="label-text">Headers</span>' + headersHtml +
      '<div class="server-actions">' +
        '<button class="secondary" onclick="App.addHeaderRow(document.getElementById(\'edit-h-' + s.id + '-headers\'))">+ Header</button>' +
        '<button onclick="App.saveServer(\'' + s.id + '\')">Save</button>' +
        '<button class="secondary" onclick="App.cancelEdit()">Cancel</button>' +
      '</div></div>';
  },

  render: function() {
    var container = document.getElementById('servers');
    if (this.servers.length === 0) {
      container.innerHTML = '<div class="empty">No servers configured yet.</div>';
      return;
    }
    var html = '';
    for (var i = 0; i < this.servers.length; i++) {
      var s = this.servers[i];
      if (this.editing === s.id) { html += this.renderEditCard(s); continue; }
      var statusClass = s.enabled ? 'enabled' : 'disabled';
      var headersHtml = '';
      if (s.headers && s.headers.length > 0) {
        var names = [];
        for (var j = 0; j < s.headers.length; j++) names.push(s.headers[j].key);
        headersHtml = '<div class="server-headers-display">Headers: ' + this.esc(names.join(', ')) + '</div>';
      }
      var oauthHtml = s.oauthProvider ? '<div class="server-detail">OAuth: <span class="badge connected">' + this.esc(s.oauthProvider) + '</span></div>' : '';
      var modeHtml = '<span class="badge ' + (s.mode === 'openapi' ? 'openapi' : 'proxy-badge') + '">' + s.mode + '</span>';
      var specHtml = (s.mode === 'openapi' && s.schemaUrl) ? '<div class="server-detail">Schema: ' + this.esc(s.schemaUrl) + (s.hasCachedSpec ? ' <span class="badge connected">cached</span>' : ' <span class="badge disconnected">not cached</span>') + '</div>' : '';
      html += '<div class="server-card">' +
        '<div class="server-header"><span class="server-name">' + this.esc(s.name) + ' <span class="server-id">' + this.esc(s.id) + '</span></span>' +
        '<span>' + modeHtml + ' <span class="badge ' + statusClass + '">' + (s.enabled ? 'enabled' : 'disabled') + '</span></span></div>' +
        '<div class="server-url">' + this.esc(s.url) + '</div>' +
        headersHtml + specHtml + oauthHtml +
        '<div class="server-actions">' +
          '<button onclick="App.editServer(\'' + s.id + '\')">Edit</button>' +
          '<button class="secondary" onclick="App.showTools(\'' + s.id + '\')">Tools</button>' +
          (s.mode === 'openapi' ? '<button class="secondary" onclick="App.refreshSpec(\'' + s.id + '\')">Reload Schema</button>' : '') +
          '<button onclick="App.toggleServer(\'' + s.id + '\')">' + (s.enabled ? 'Disable' : 'Enable') + '</button>' +
          '<button class="danger" onclick="App.removeServer(\'' + s.id + '\')">Remove</button>' +
        '</div>' +
        '<div id="server-tools-' + s.id + '"></div>' +
        '</div>';
    }
    container.innerHTML = html;
    if (this.editing) {
      var s = this.servers.find(function(x) { return x.id === App.editing; });
      if (s) { var sel = document.querySelector('.edit-oauth'); if (sel) sel.value = s.oauthProvider || ''; }
    }
  },

  renderOAuth: function() {
    var container = document.getElementById('oauth-providers');
    if (this.oauthProviders.length === 0) {
      container.innerHTML = '<div class="empty">No OAuth providers configured.</div>';
      return;
    }
    var html = '';
    for (var i = 0; i < this.oauthProviders.length; i++) {
      var p = this.oauthProviders[i];
      var status = p.hasGrant ? 'connected' : 'disconnected';
      html += '<div class="server-card">' +
        '<div class="server-header"><span class="server-name">' + this.esc(p.id) + '</span>' +
        '<span class="badge ' + status + '">' + status + '</span></div>' +
        '<div class="server-url">Scopes: ' + this.esc(p.scopes) + '</div>' +
        '<div class="server-actions">' +
          (p.hasGrant
            ? '<button class="danger" onclick="App.disconnectProvider(\'' + p.id + '\')">Disconnect</button>'
            : '<button onclick="App.connectProvider(\'' + p.id + '\')">Connect</button>') +
          '<button class="secondary" onclick="App.removeProvider(\'' + p.id + '\')">Remove</button>' +
        '</div></div>';
    }
    container.innerHTML = html;
  },

  esc: function(str) {
    if (!str) return '';
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }
};

document.addEventListener('DOMContentLoaded', function() { App.init(); });
