::  mcp-proxy: proxy for remote MCP servers
::
::    configure remote MCP server endpoints via the web UI,
::    then point an LLM at /mcp-proxy/mcp/{server-id}
::    to proxy MCP requests through your urbit ship.
::
/-  mcp-proxy
/+  default-agent, dbug, server
|%
+$  card  card:agent:gall
--
::
%-  agent:dbug
=|  state-0:mcp-proxy
=*  state  -
=/  pending  *(map @t @ta)          ::  wire-id -> eyre-id for proxy reqs
=/  cookies  *(map server-id:mcp-proxy @t)  ::  cached auth cookies
^-  agent:gall
=<
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init
  ^-  (quip card _this)
  :_  this
  :~  [%pass /eyre/connect %arvo %e %connect [~ /mcp-proxy/api] %mcp-proxy]
      [%pass /eyre/mcp %arvo %e %connect [~ /mcp-proxy/mcp] %mcp-proxy]
  ==
::
++  on-save  !>(state)
::
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  =/  old  (mule |.(!<(versioned-state:mcp-proxy old-state)))
  ?:  ?=(%| -.old)
    on-init
  ?-  -.p.old
      %0
    :_  this(state p.old)
    :~  [%pass /eyre/connect %arvo %e %connect [~ /mcp-proxy/api] %mcp-proxy]
        [%pass /eyre/mcp %arvo %e %connect [~ /mcp-proxy/mcp] %mcp-proxy]
    ==
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^
  ?+  mark  (on-poke:def mark vase)
      %mcp-proxy-action
    (handle-action !<(action:mcp-proxy vase))
  ::
      %json
    =/  jon=json  !<(json vase)
    =/  act=(unit action:mcp-proxy)  (parse-json-action jon)
    ?~  act  `this
    (handle-action u.act)
  ::
      %handle-http-request
    =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
    (handle-http eyre-id req)
  ==
  ::
  ++  handle-action
    |=  act=action:mcp-proxy
    ^-  (quip card _this)
    ?>  =(src.bowl our.bowl)
    ?-  -.act
        %add-server
      ?:  (~(has by servers) id.act)
        `this
      =.  servers  (~(put by servers) id.act mcp-server.act)
      =.  server-order  (snoc server-order id.act)
      `this
    ::
        %remove-server
      =.  servers  (~(del by servers) id.act)
      =.  server-order  (skip server-order |=(s=server-id:mcp-proxy =(s id.act)))
      =.  cookies  (~(del by cookies) id.act)
      `this
    ::
        %update-server
      =.  servers  (~(put by servers) id.act mcp-server.act)
      `this
    ::
        %toggle-server
      =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) id.act)
      ?~  srv  `this
      =.  servers  (~(put by servers) id.act u.srv(enabled !enabled.u.srv))
      `this
    ::
        %login-server
      ~&  [%mcp-proxy %login-action id.act]
      =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) id.act)
      ?~  srv
        ~&  [%mcp-proxy %server-not-found id.act]
        `this
      ~&  [%mcp-proxy %found-server name.u.srv url.u.srv]
      (do-login id.act u.srv)
    ==
  ::
  ++  do-login
    |=  [sid=server-id:mcp-proxy srv=mcp-server:mcp-proxy]
    ^-  (quip card _this)
    ::  scry for +code
    ::
    =/  code=@p
      .^(@p %j /(scot %p our.bowl)/code/(scot %da now.bowl)/(scot %p our.bowl))
    =/  pass=@t  (scot %p code)
    ::  extract base url from server url (scheme + host + port)
    ::
    =/  base=@t  (get-base-url url.srv)
    =/  login-url=@t  (cat 3 base '/~/login')
    =/  body=@t  (cat 3 'password=' pass)
    ~&  [%mcp-proxy %logging-in login-url]
    :_  this
    :~  :*  %pass  /iris/login/[sid]
            %arvo  %i
            %request
            [%'POST' login-url ~[['content-type' 'application/x-www-form-urlencoded']] `(as-octs:mimes:html body)]
            *outbound-config:iris
        ==
    ==
  ::
  ++  handle-http
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  rl=request-line:server  (parse-request-line:server url.request.req)
    =/  site=(list @t)  site.rl
    ::  MCP proxy endpoint: no auth required
    ::
    ?:  ?=([%mcp-proxy %mcp *] site)
      (handle-mcp eyre-id req t.t.site)
    ::  API endpoints
    ::
    ?.  ?=([%mcp-proxy %api *] site)
      :_  this
      (give-http eyre-id 404 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'not found')))
    =/  api-path=(list @t)  t.t.site
    ?.  authenticated.req
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      (login-redirect:gen:server request.req)
    ?:  =(%'GET' method.request.req)
      (handle-get eyre-id api-path)
    ?:  =(%'POST' method.request.req)
      (handle-post eyre-id req)
    :_  this
    (give-http eyre-id 405 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'method not allowed')))
  ::
  ++  handle-get
    |=  [eyre-id=@ta site=(list @t)]
    ^-  (quip card _this)
    ?+  site
      :_  this
      (give-http eyre-id 404 ~[['content-type' 'text/plain']] (some (as-octs:mimes:html 'not found')))
    ::
        [%servers ~]
      :_  this
      (give-json eyre-id (build-servers-json ~))
    ==
  ::
  ++  handle-post
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  body=@t
      ?~  body.request.req  ''
      `@t`q.u.body.request.req
    =/  jon=(unit json)  (de:json:html body)
    ?~  jon
      :_  this
      (give-http eyre-id 400 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"bad json"}')))
    =/  act=(unit action:mcp-proxy)  (parse-json-action u.jon)
    ?~  act
      :_  this
      (give-http eyre-id 400 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"bad action"}')))
    =/  result  (handle-action u.act)
    :_  +.result
    %+  weld  -.result
    (give-http eyre-id 200 ~[['content-type' 'application/json']] (some (as-octs:mimes:html '{"ok":true}')))
  ::
  ++  handle-mcp
    |=  [eyre-id=@ta req=inbound-request:eyre site=(list @t)]
    ^-  (quip card _this)
    ::  CORS preflight
    ::
    ?:  =(%'OPTIONS' method.request.req)
      :_  this
      %-  give-http  :^  eyre-id  204
      :~  ['access-control-allow-origin' '*']
          ['access-control-allow-methods' 'GET, POST, DELETE, OPTIONS']
          ['access-control-allow-headers' 'Content-Type, Accept, Authorization, Mcp-Session-Id']
          ['access-control-expose-headers' 'Mcp-Session-Id']
          ['access-control-max-age' '86400']
      ==
      ~
    ::  need server id
    ::
    ?~  site
      :_  this
      %-  give-http  :^  eyre-id  400
      ~[['content-type' 'application/json'] ['access-control-allow-origin' '*']]
      (some (as-octs:mimes:html '{"error":"missing server id"}'))
    =/  sid=server-id:mcp-proxy  i.site
    =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) sid)
    ?~  srv
      :_  this
      %-  give-http  :^  eyre-id  404
      ~[['content-type' 'application/json'] ['access-control-allow-origin' '*']]
      (some (as-octs:mimes:html '{"error":"server not found"}'))
    ?.  enabled.u.srv
      :_  this
      %-  give-http  :^  eyre-id  503
      ~[['content-type' 'application/json'] ['access-control-allow-origin' '*']]
      (some (as-octs:mimes:html '{"error":"server disabled"}'))
    ::  build outbound headers
    ::
    =/  out-headers=(list [key=@t value=@t])
      %+  weld
        ~[['content-type' 'application/json'] ['accept' 'application/json, text/event-stream']]
      headers.u.srv
    ::  add cached auth cookie if we have one
    ::
    =/  cookie=(unit @t)  (~(get by cookies) sid)
    =?  out-headers  ?=(^ cookie)
      (snoc out-headers ['cookie' u.cookie])
    ::  forward mcp-session-id if present
    ::
    =/  session-id=(unit @t)
      =/  hdrs=(list [key=@t value=@t])  header-list.request.req
      |-
      ?~  hdrs  ~
      ?:  =(key.i.hdrs 'mcp-session-id')  `value.i.hdrs
      $(hdrs t.hdrs)
    =?  out-headers  ?=(^ session-id)
      (snoc out-headers ['mcp-session-id' u.session-id])
    ::  store pending and send iris request
    ::
    =/  wire-id=@t  (scot %uv `@uv`eny.bowl)
    =.  pending  (~(put by pending) wire-id eyre-id)
    :_  this
    :~  :*  %pass  /iris/proxy/[wire-id]
            %arvo  %i
            %request
            [method.request.req url.u.srv out-headers body.request.req]
            *outbound-config:iris
        ==
    ==
  ::
  ++  build-servers-json
    |=  ~
    ^-  json
    =,  enjs:format
    %-  pairs
    :~  ['ship' s+(scot %p our.bowl)]
        :-  'servers'
        :-  %a
        %+  turn  server-order
        |=  sid=server-id:mcp-proxy
        =/  srv=mcp-server:mcp-proxy  (~(got by servers) sid)
        =/  has-cookie=?  (~(has by cookies) sid)
        %-  pairs
        :~  ['id' s+(scot %tas sid)]
            ['name' s+name.srv]
            ['url' s+url.srv]
            ['enabled' b+enabled.srv]
            ['authenticated' b+has-cookie]
            :-  'headers'
            :-  %a
            %+  turn  headers.srv
            |=  h=header:mcp-proxy
            (pairs ~[['key' s+key.h] ['value' s+value.h]])
        ==
    ==
  --
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%http-response @ ~]
    `this
  ==
::
++  on-arvo
  |=  [=wire sign=sign-arvo]
  ^-  (quip card _this)
  ?+  wire  `this
      [%eyre *]
    ?:  ?=(%bound +<.sign)
      ~?  !accepted.sign  [%mcp-proxy %binding-rejected binding.sign]
      `this
    `this
  ::
      [%iris %login @ ~]
    ::  handle login response - extract cookie
    ::
    =/  sid=server-id:mcp-proxy  i.t.t.wire
    ?.  ?=([%iris %http-response *] sign)
      ~&  [%mcp-proxy %login-failed sid %bad-sign]
      `this
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      ~&  [%mcp-proxy %login-failed sid %not-finished]
      `this
    ?.  =(200 status-code.response-header.resp)
      ~&  [%mcp-proxy %login-failed sid %status status-code.response-header.resp]
      `this
    ::  extract set-cookie header
    ::
    =/  cookie=(unit @t)
      =/  hdrs=(list [key=@t value=@t])  headers.response-header.resp
      |-
      ?~  hdrs  ~
      ?:  =(key.i.hdrs 'set-cookie')
        ::  extract just the cookie key=val (before the ;)
        ::
        =/  val=tape  (trip value.i.hdrs)
        =/  semi=(unit @ud)  (find ";" val)
        ?~  semi  `value.i.hdrs
        `(crip (scag u.semi val))
      $(hdrs t.hdrs)
    ?~  cookie
      ~&  [%mcp-proxy %login-failed sid %no-cookie]
      `this
    ~&  [%mcp-proxy %login-ok sid]
    `this(cookies (~(put by cookies) sid u.cookie))
  ::
      [%iris %proxy @ ~]
    ::  handle proxy response - forward to client
    ::
    =/  wire-id=@t  i.t.t.wire
    =/  eid=(unit @ta)  (~(get by pending) wire-id)
    ?~  eid
      ~&  [%mcp-proxy %no-pending wire-id]
      `this
    =.  pending  (~(del by pending) wire-id)
    ?.  ?=([%iris %http-response *] sign)
      :_  this
      %-  give-http  :^  u.eid  502
      ~[['content-type' 'application/json'] ['access-control-allow-origin' '*']]
      (some (as-octs:mimes:html '{"error":"unexpected iris response"}'))
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      :_  this
      %-  give-http  :^  u.eid  502
      ~[['content-type' 'application/json'] ['access-control-allow-origin' '*']]
      (some (as-octs:mimes:html '{"error":"upstream in progress"}'))
    ::  forward upstream headers, stripping hop-by-hop headers
    ::
    =/  resp-headers=(list [key=@t value=@t])
      %+  weld
        ~[['access-control-allow-origin' '*'] ['access-control-expose-headers' 'Mcp-Session-Id']]
      %+  skip  headers.response-header.resp
      |=  [key=@t value=@t]
      ?|  =(key 'transfer-encoding')
          =(key 'connection')
      ==
    =/  bod=(unit octs)
      ?~  full-file.resp  ~
      `data.u.full-file.resp
    :_  this
    =/  =path  /http-response/[u.eid]
    :~  [%give %fact ~[path] %http-response-header !>(`response-header:http`[status-code.response-header.resp resp-headers])]
        [%give %fact ~[path] %http-response-data !>(bod)]
        [%give %kick ~[path] ~]
    ==
  ==
::
++  on-leave  on-leave:def
++  on-agent  on-agent:def
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  ~
      [%x %dbug %state ~]  ``noun+!>(state)
  ==
::
++  on-fail  on-fail:def
--
::
::  helper core
::
|%
++  get-base-url
  |=  url=@t
  ^-  @t
  =/  t=tape  (trip url)
  ::  find :// then find next / after that
  ::
  =/  scheme-mark=(unit @ud)  (find "://" t)
  ?~  scheme-mark  url
  =/  after-scheme=@ud  (add 3 u.scheme-mark)
  =/  rest=tape  (slag after-scheme t)
  =/  path-start=(unit @ud)  (find "/" rest)
  ?~  path-start  url
  (crip (scag (add after-scheme u.path-start) t))
::
++  parse-json-action
  |=  jon=json
  ^-  (unit action:mcp-proxy)
  =/  res  (mule |.((parse-json-action-raw jon)))
  ?:  ?=(%& -.res)  `p.res
  ~
::
++  parse-json-action-raw
  |=  jon=json
  ^-  action:mcp-proxy
  =,  dejs:format
  =/  typ=@t  ((ot ~[action+so]) jon)
  ?+  typ  !!
      %'add-server'
    =/  f
      %-  ot
      :~  id+so
          name+so
          url+so
          headers+(ar (ot ~[key+so value+so]))
      ==
    =/  [id=@t name=@t url=@t headers=(list header:mcp-proxy)]
      (f jon)
    [%add-server `@tas`id [name url headers %.y]]
  ::
      %'remove-server'
    [%remove-server `@tas`((ot ~[id+so]) jon)]
  ::
      %'update-server'
    =/  f
      %-  ot
      :~  id+so
          name+so
          url+so
          headers+(ar (ot ~[key+so value+so]))
          enabled+bo
      ==
    =/  [id=@t name=@t url=@t headers=(list header:mcp-proxy) enabled=?]
      (f jon)
    [%update-server `@tas`id [name url headers enabled]]
  ::
      %'toggle-server'
    [%toggle-server `@tas`((ot ~[id+so]) jon)]
  ::
      %'login-server'
    [%login-server `@tas`((ot ~[id+so]) jon)]
  ==
::
++  server-to-json
  |=  [sid=server-id:mcp-proxy srv=mcp-server:mcp-proxy]
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  ['id' s+(scot %tas sid)]
      ['name' s+name.srv]
      ['url' s+url.srv]
      ['enabled' b+enabled.srv]
      :-  'headers'
      :-  %a
      %+  turn  headers.srv
      |=  h=header:mcp-proxy
      (pairs ~[['key' s+key.h] ['value' s+value.h]])
  ==
::
++  give-http
  |=  [eyre-id=@ta status=@ud headers=(list [@t @t]) body=(unit octs)]
  ^-  (list card)
  %+  give-simple-payload:app:server  eyre-id
  [[status headers] body]
::
++  give-json
  |=  [eyre-id=@ta jon=json]
  ^-  (list card)
  %+  give-simple-payload:app:server  eyre-id
  (json-response:gen:server jon)
--
