var App = {
  servers: [],
  editing: null,

  init: function() {
    var url = window.location.origin + '/mcp-proxy/mcp';
    document.getElementById('agg-url').textContent = url;
    this.loadServers();
    this.bindEvents();
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

  loadServers: function() {
    var self = this;
    McpProxyAPI.getServers().then(function(data) {
      self.ship = data.ship || '';
      self.servers = data.servers || [];
      self.render();
      self.updateEndpoint();
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
      var id = form.elements.id.value.trim().toLowerCase().replace(/[^a-z0-9-]/g, '').replace(/^-+/, '').replace(/-+$/, '');
      var name = form.elements.name.value.trim();
      var url = form.elements.url.value.trim();
      var headers = self.getHeadersFromForm('add');
      if (!id || !name || !url) return;
      McpProxyAPI.addServer(id, name, url, headers).then(function() {
        form.reset();
        var rows = document.querySelectorAll('#add-headers .header-row');
        for (var i = 0; i < rows.length; i++) rows[i].remove();
        self.loadServers();
        self.toast('Server added');
      }).catch(function(e) {
        alert('Failed to add server: ' + e.message);
      });
    });

    document.getElementById('add-header-btn').addEventListener('click', function() {
      self.addHeaderRow(document.getElementById('add-headers'));
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
    k.type = 'text';
    k.className = 'header-key';
    k.placeholder = 'Header name';
    k.value = key || '';
    var v = document.createElement('input');
    v.type = 'text';
    v.className = 'header-value';
    v.placeholder = 'Header value';
    v.value = value || '';
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = '\u00d7';
    btn.addEventListener('click', function() { row.remove(); });
    row.appendChild(k);
    row.appendChild(v);
    row.appendChild(btn);
    container.appendChild(row);
  },

  editServer: function(id) {
    this.editing = id;
    this.render();
  },

  cancelEdit: function() {
    this.editing = null;
    this.render();
  },

  saveServer: function(id) {
    var self = this;
    var card = document.getElementById('edit-' + id);
    var name = card.querySelector('.edit-name').value.trim();
    var url = card.querySelector('.edit-url').value.trim();
    var headers = this.getHeadersFromForm('edit-h-' + id);
    var s = this.servers.find(function(x) { return x.id === id; });
    if (!name || !url) return;
    McpProxyAPI.updateServer(id, name, url, headers, s ? s.enabled : true).then(function() {
      self.editing = null;
      self.loadServers();
      self.toast('Server updated');
    }).catch(function(e) {
      alert('Failed: ' + e.message);
    });
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

  renderEditCard: function(s) {
    var headersHtml = '<div id="edit-h-' + s.id + '-headers">';
    if (s.headers) {
      for (var j = 0; j < s.headers.length; j++) {
        headersHtml += '<div class="header-row">' +
          '<input type="text" class="header-key" value="' + this.esc(s.headers[j].key) + '">' +
          '<input type="text" class="header-value" value="' + this.esc(s.headers[j].value) + '">' +
          '<button type="button" onclick="this.parentElement.remove()">\u00d7</button>' +
          '</div>';
      }
    }
    headersHtml += '</div>';
    return '<div class="server-card editing" id="edit-' + s.id + '">' +
      '<div class="form-row">' +
        '<label>Name<input type="text" class="edit-name" value="' + this.esc(s.name) + '"></label>' +
      '</div>' +
      '<div class="form-row">' +
        '<label>URL<input type="url" class="edit-url" value="' + this.esc(s.url) + '"></label>' +
      '</div>' +
      '<span class="label-text">Headers</span>' +
      headersHtml +
      '<div class="server-actions">' +
        '<button class="secondary" onclick="App.addHeaderRow(document.getElementById(\'edit-h-' + s.id + '-headers\'))">+ Header</button>' +
        '<button onclick="App.saveServer(\'' + s.id + '\')">Save</button>' +
        '<button class="secondary" onclick="App.cancelEdit()">Cancel</button>' +
      '</div>' +
    '</div>';
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
      if (this.editing === s.id) {
        html += this.renderEditCard(s);
        continue;
      }
      var statusClass = s.enabled ? 'enabled' : 'disabled';
      var statusText = s.enabled ? 'enabled' : 'disabled';
      var headersHtml = '';
      if (s.headers && s.headers.length > 0) {
        var names = [];
        for (var j = 0; j < s.headers.length; j++) names.push(s.headers[j].key);
        headersHtml = '<div class="server-headers-display">Headers: ' + this.esc(names.join(', ')) + '</div>';
      }
      html += '<div class="server-card">' +
        '<div class="server-header">' +
          '<span class="server-name">' + this.esc(s.name) + ' <span class="server-id">' + this.esc(s.id) + '</span></span>' +
          '<span class="badge ' + statusClass + '">' + statusText + '</span>' +
        '</div>' +
        '<div class="server-url">' + this.esc(s.url) + '</div>' +
        headersHtml +
        '<div class="server-actions">' +
          '<button onclick="App.editServer(\'' + s.id + '\')">Edit</button>' +
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
