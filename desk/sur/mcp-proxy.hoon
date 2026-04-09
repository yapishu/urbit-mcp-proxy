::  mcp-proxy: types for MCP server proxy
::
|%
+$  server-id  @tas
::
+$  header  [key=@t value=@t]
::
::  old server type (for state migration)
+$  mcp-server-0
  $:  name=@t
      url=@t
      headers=(list header)
      enabled=?
  ==
::
+$  mcp-server
  $:  name=@t
      url=@t
      headers=(list header)
      enabled=?
      oauth-provider=(unit @tas)
  ==
::
+$  state-0
  $:  %0
      servers=(map server-id mcp-server-0)
      server-order=(list server-id)
  ==
::
+$  state-1
  $:  %1
      servers=(map server-id mcp-server)
      server-order=(list server-id)
  ==
::
+$  versioned-state
  $%  state-0
      state-1
  ==
::
+$  action
  $%  [%add-server id=server-id =mcp-server]
      [%remove-server id=server-id]
      [%update-server id=server-id =mcp-server]
      [%toggle-server id=server-id]
      [%login-server id=server-id]
  ==
::
+$  update
  $%  [%server-added id=server-id =mcp-server]
      [%server-removed id=server-id]
      [%server-updated id=server-id =mcp-server]
  ==
--
