::  mcp-proxy: types for MCP server proxy
::
|%
+$  server-id  @tas
::
+$  header  [key=@t value=@t]
::
+$  server-mode  ?(%proxy %openapi)
::
+$  tool-filter
  $:  mode=?(%allow %block)
      tools=(set @t)
  ==
::
::  old types for state migration
+$  mcp-server-0
  $:  name=@t
      url=@t
      headers=(list header)
      enabled=?
  ==
::
+$  mcp-server-1
  $:  name=@t
      url=@t
      headers=(list header)
      enabled=?
      oauth-provider=(unit @tas)
  ==
::
+$  mcp-server
  $:  name=@t
      url=@t
      headers=(list header)
      enabled=?
      oauth-provider=(unit @tas)
      mode=server-mode
      schema-url=(unit @t)
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
      servers=(map server-id mcp-server-1)
      server-order=(list server-id)
  ==
::
+$  state-2
  $:  %2
      servers=(map server-id mcp-server)
      server-order=(list server-id)
  ==
::
+$  state-3
  $:  %3
      servers=(map server-id mcp-server)
      server-order=(list server-id)
      tool-filters=(map server-id tool-filter)
  ==
::
+$  versioned-state
  $%  state-0
      state-1
      state-2
      state-3
  ==
::
+$  action
  $%  [%add-server id=server-id =mcp-server]
      [%remove-server id=server-id]
      [%update-server id=server-id =mcp-server]
      [%toggle-server id=server-id]
      [%login-server id=server-id]
      [%refresh-spec id=server-id]
      [%set-tool-filter id=server-id =tool-filter]
      [%clear-tool-filter id=server-id]
  ==
::
+$  update
  $%  [%server-added id=server-id =mcp-server]
      [%server-removed id=server-id]
      [%server-updated id=server-id =mcp-server]
  ==
--
