window.McpProxyAPI = {
  base: '/mcp-proxy/api',

  async get(path) {
    const res = await fetch(this.base + path, { credentials: 'include' });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    return res.json();
  },

  async post(data) {
    const res = await fetch(this.base, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    return res.json();
  },

  getServers() { return this.get('/servers'); },

  addServer(id, name, url, headers) {
    return this.post({ action: 'add-server', id: id, name: name, url: url, headers: headers });
  },

  removeServer(id) {
    return this.post({ action: 'remove-server', id: id });
  },

  updateServer(id, name, url, headers, enabled) {
    return this.post({ action: 'update-server', id: id, name: name, url: url, headers: headers, enabled: enabled });
  },

  toggleServer(id) {
    return this.post({ action: 'toggle-server', id: id });
  },

  loginServer(id) {
    return this.post({ action: 'login-server', id: id });
  }
};
