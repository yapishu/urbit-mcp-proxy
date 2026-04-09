window.McpProxyAPI = {
  base: '/mcp-proxy/api',

  async get(path) {
    var res = await fetch(this.base + path, { credentials: 'include' });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    return res.json();
  },

  async post(data) {
    var res = await fetch(this.base, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    return res.json();
  },

  getServers: function() { return this.get('/servers'); },

  addServer: function(id, name, url, headers, opts) {
    var data = { action: 'add-server', id: id, name: name, url: url, headers: headers };
    if (opts.oauthProvider) data['oauth-provider'] = opts.oauthProvider;
    if (opts.mode) data.mode = opts.mode;
    if (opts.schemaUrl) data['schema-url'] = opts.schemaUrl;
    return this.post(data);
  },

  removeServer: function(id) {
    return this.post({ action: 'remove-server', id: id });
  },

  updateServer: function(id, name, url, headers, enabled, opts) {
    var data = { action: 'update-server', id: id, name: name, url: url, headers: headers, enabled: enabled };
    if (opts.oauthProvider) data['oauth-provider'] = opts.oauthProvider;
    if (opts.mode) data.mode = opts.mode;
    if (opts.schemaUrl) data['schema-url'] = opts.schemaUrl;
    return this.post(data);
  },

  toggleServer: function(id) {
    return this.post({ action: 'toggle-server', id: id });
  },

  refreshSpec: function(id) {
    return this.post({ action: 'refresh-spec', id: id });
  }
};

window.OAuthAPI = {
  base: '/oauth/api',

  async get(path) {
    var res = await fetch(this.base + path, { credentials: 'include' });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    return res.json();
  },

  async post(data) {
    var res = await fetch(this.base, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    return res.json();
  },

  getProviders: function() { return this.get('/providers'); },
  getGrants: function() { return this.get('/grants'); },

  addProvider: function(data) { return this.post(data); },
  removeProvider: function(id) { return this.post({ action: 'remove-provider', id: id }); },
  connect: function(id) { return this.post({ action: 'connect', id: id }); },
  disconnect: function(id) { return this.post({ action: 'disconnect', id: id }); }
};
