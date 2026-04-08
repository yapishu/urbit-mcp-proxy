var App = {
  servers: [],

  init: function() {
    this.loadServers();
    this.bindEvents();
  },

  loadServers: function() {
    var self = this;
    McpProxyAPI.getServers().then(function(data) {
      self.servers = data.servers || [];
      self.render();
    }).catch(function(e) {
      console.error('Failed to load servers:', e);
      self.servers = [];
      self.render();
    });
  },

  bindEvents: function() {
    var self = this;
    document.getElementById('add-form').addEventListener('submit', function(e) {
      e.preventDefault();
      var form = e.target;
      var id = form.elements.id.value.trim().toLowerCase().replace(/[^a-z0-9-]/g, '-');
      var name = form.elements.name.value.trim();
      var url = form.elements.url.value.trim();
      var headers = self.getHeadersFromForm();
      if (!id || !name || !url) return;
      McpProxyAPI.addServer(id, name, url, headers).then(function() {
        form.reset();
        var rows = document.querySelectorAll('.header-row');
        for (var i = 0; i < rows.length; i++) rows[i].remove();
        self.loadServers();
        self.toast('Server added');
      }).catch(function(e) {
        alert('Failed to add server: ' + e.message);
      });
    });

    document.getElementById('add-header-btn').addEventListener('click', function() {
      self.addHeaderRow();
    });
  },

  getHeadersFromForm: function() {
    var rows = document.querySelectorAll('.header-row');
    var headers = [];
    for (var i = 0; i < rows.length; i++) {
      var key = rows[i].querySelector('.header-key').value.trim();
      var value = rows[i].querySelector('.header-value').value.trim();
      if (key && value) headers.push({ key: key, value: value });
    }
    return headers;
  },

  addHeaderRow: function() {
    var container = document.getElementById('headers-container');
    var row = document.createElement('div');
    row.className = 'header-row';
    var k = document.createElement('input');
    k.type = 'text';
    k.className = 'header-key';
    k.placeholder = 'Header name';
    var v = document.createElement('input');
    v.type = 'text';
    v.className = 'header-value';
    v.placeholder = 'Header value';
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = '\u00d7';
    btn.addEventListener('click', function() { row.remove(); });
    row.appendChild(k);
    row.appendChild(v);
    row.appendChild(btn);
    container.appendChild(row);
  },

  toggleServer: function(id) {
    var self = this;
    McpProxyAPI.toggleServer(id).then(function() {
      self.loadServers();
    }).catch(function(e) {
      alert('Failed: ' + e.message);
    });
  },

  removeServer: function(id) {
    if (!confirm('Remove this server?')) return;
    var self = this;
    McpProxyAPI.removeServer(id).then(function() {
      self.loadServers();
      self.toast('Server removed');
    }).catch(function(e) {
      alert('Failed: ' + e.message);
    });
  },

  loginServer: function(id) {
    var self = this;
    McpProxyAPI.loginServer(id).then(function() {
      self.toast('Login initiated - refreshing...');
      setTimeout(function() { self.loadServers(); }, 1500);
    }).catch(function(e) {
      alert('Failed: ' + e.message);
    });
  },

  copyUrl: function(text) {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text);
      this.toast('Copied to clipboard');
    }
  },

  toast: function(msg) {
    var el = document.getElementById('toast');
    if (!el) {
      el = document.createElement('div');
      el.id = 'toast';
      el.className = 'toast';
      document.body.appendChild(el);
    }
    el.textContent = msg;
    el.classList.add('show');
    setTimeout(function() { el.classList.remove('show'); }, 2000);
  },

  render: function() {
    var container = document.getElementById('servers');
    if (this.servers.length === 0) {
      container.innerHTML = '<div class="empty">No servers configured yet. Add one above.</div>';
      return;
    }
    var html = '';
    for (var i = 0; i < this.servers.length; i++) {
      var s = this.servers[i];
      var proxyUrl = window.location.origin + '/mcp-proxy/mcp/' + s.id;
      var statusClass = s.enabled ? 'enabled' : 'disabled';
      var statusText = s.enabled ? 'enabled' : 'disabled';
      var headersHtml = '';
      if (s.headers && s.headers.length > 0) {
        var names = [];
        for (var j = 0; j < s.headers.length; j++) names.push(s.headers[j].key);
        headersHtml = '<div class="server-headers-display">Headers: ' + this.esc(names.join(', ')) + '</div>';
      }
      var authClass = s.authenticated ? 'enabled' : 'disabled';
      var authText = s.authenticated ? 'authed' : 'no auth';
      html += '<div class="server-card">' +
        '<div class="server-header">' +
          '<span class="server-name">' + this.esc(s.name) + ' <span class="server-id">' + this.esc(s.id) + '</span></span>' +
          '<span><span class="badge ' + statusClass + '">' + statusText + '</span> <span class="badge ' + authClass + '">' + authText + '</span></span>' +
        '</div>' +
        '<div class="server-url">' + this.esc(s.url) + '</div>' +
        headersHtml +
        '<div class="server-proxy">Proxy endpoint: <code onclick="App.copyUrl(\'' + this.esc(proxyUrl) + '\')">' + this.esc(proxyUrl) + '</code></div>' +
        '<div class="server-actions">' +
          '<button onclick="App.loginServer(\'' + s.id + '\')">Login (+code)</button>' +
          '<button onclick="App.toggleServer(\'' + s.id + '\')">' + (s.enabled ? 'Disable' : 'Enable') + '</button>' +
          '<button class="danger" onclick="App.removeServer(\'' + s.id + '\')">Remove</button>' +
        '</div>' +
      '</div>';
    }
    container.innerHTML = html;
  },

  esc: function(str) {
    if (!str) return '';
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }
};

document.addEventListener('DOMContentLoaded', function() { App.init(); });
