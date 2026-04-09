::  mcp-proxy: proxy for remote MCP servers
::
::    configure remote MCP server endpoints via the web UI.
::    point an LLM at /mcp-proxy/mcp for an aggregate endpoint
::    that combines tools from all configured servers.
::    or /mcp-proxy/mcp/{server-id} for a single server.
::
/-  mcp-proxy
/-  oauth
/+  default-agent, dbug, server
|%
+$  card  card:agent:gall
::
+$  agg-request
  $:  eyre-id=@ta
      req-id=json
      method=@t
      total=@ud
      results=(map server-id:mcp-proxy (unit json))
  ==
--
::
%-  agent:dbug
=|  state-1:mcp-proxy
=*  state  -
=/  pending  *(map @t @ta)
=/  cookies  *(map server-id:mcp-proxy @t)
=/  agg-pending  *(map @t agg-request)
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
      %1
    :_  this(state p.old)
    :~  [%pass /eyre/connect %arvo %e %connect [~ /mcp-proxy/api] %mcp-proxy]
        [%pass /eyre/mcp %arvo %e %connect [~ /mcp-proxy/mcp] %mcp-proxy]
    ==
  ::
      %0
    =/  new-servers=(map server-id:mcp-proxy mcp-server:mcp-proxy)
      %-  ~(run by servers.p.old)
      |=(s=mcp-server-0:mcp-proxy [name.s url.s headers.s enabled.s ~])
    :_  this(state [%1 new-servers server-order.p.old])
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
  ::
      %noun
    ::  clear eyre cache for web UI files
    =/  urls=(list @t)
      :~  '/apps/mcp-proxy/'
          '/apps/mcp-proxy/index.html'
          '/apps/mcp-proxy/css/app.css'
          '/apps/mcp-proxy/js/app.js'
          '/apps/mcp-proxy/js/api.js'
      ==
    ~&  [%mcp-proxy %clearing-eyre-cache (lent urls)]
    :_  this
    %+  turn  urls
    |=(url=@t [%pass /eyre/cache %arvo %e %set-response url ~])
  ==
  ::
  ++  handle-action
    |=  act=action:mcp-proxy
    ^-  (quip card _this)
    ?>  =(src.bowl our.bowl)
    ?-  -.act
        %add-server
      ?:  (~(has by servers) id.act)  `this
      =.  servers  (~(put by servers) id.act mcp-server.act)
      =.  server-order  (snoc server-order id.act)
      `this
        %remove-server
      =.  servers  (~(del by servers) id.act)
      =.  server-order  (skip server-order |=(s=server-id:mcp-proxy =(s id.act)))
      =.  cookies  (~(del by cookies) id.act)
      `this
        %update-server
      =.  servers  (~(put by servers) id.act mcp-server.act)
      `this
        %toggle-server
      =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) id.act)
      ?~  srv  `this
      =.  servers  (~(put by servers) id.act u.srv(enabled !enabled.u.srv))
      `this
        %login-server
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
    =/  code=@p
      .^(@p %j /(scot %p our.bowl)/code/(scot %da now.bowl)/(scot %p our.bowl))
    =/  pass=@t  (scot %p code)
    =/  base=@t  (get-base-url url.srv)
    =/  login-url=@t  (cat 3 base '/~/login')
    =/  body=@t  (cat 3 'password=' pass)
    ~&  [%mcp-proxy %logging-in login-url]
    :_  this
    :~  :*  %pass  /iris/login/[sid]
            %arvo  %i  %request
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
    ?:  ?=([%mcp-proxy %mcp *] site)
      =/  rest=(list @t)  t.t.site
      ::  aggregate endpoint: /mcp-proxy/mcp or /mcp-proxy/mcp/
      ::
      ?:  |(=(~ rest) ?=([%$ ~] rest))
        (handle-agg eyre-id req)
      ::  single-server proxy: /mcp-proxy/mcp/{server-id}
      ::
      (handle-mcp eyre-id req rest)
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
      (give-http eyre-id 400 ~[cors] (some (as-octs:mimes:html '{"error":"bad json"}')))
    =/  act=(unit action:mcp-proxy)  (parse-json-action u.jon)
    ?~  act
      :_  this
      (give-http eyre-id 400 ~[cors] (some (as-octs:mimes:html '{"error":"bad action"}')))
    =/  result  (handle-action u.act)
    :_  +.result
    %+  weld  -.result
    (give-http eyre-id 200 ~[cors] (some (as-octs:mimes:html '{"ok":true}')))
  ::
  ::  aggregate endpoint: combine tools from all servers
  ::
  ++  handle-agg
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    ::  CORS
    ?:  =(%'OPTIONS' method.request.req)
      :_  this
      %-  give-http  :^  eyre-id  204
      :~  cors
          ['access-control-allow-methods' 'GET, POST, DELETE, OPTIONS']
          ['access-control-allow-headers' 'Content-Type, Accept, Authorization, Mcp-Session-Id']
          ['access-control-expose-headers' 'Mcp-Session-Id']
          ['access-control-max-age' '86400']
      ==
      ~
    =/  body=@t
      ?~  body.request.req  ''
      `@t`q.u.body.request.req
    =/  jon=(unit json)  (de:json:html body)
    ?~  jon
      :_  this
      (give-http eyre-id 400 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"bad json"}')))
    =/  method=@t  (get-json-string u.jon 'method')
    =/  req-id=json  (get-json-field u.jon 'id')
    ::
    ?+  method
      :_  this
      (give-http eyre-id 400 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html '{"error":"unknown method"}')))
    ::
        %'initialize'
      :_  this
      =/  resp=json
        %-  pairs:enjs:format
        :~  ['jsonrpc' s+'2.0']
            ['id' req-id]
            :-  'result'
            %-  pairs:enjs:format
            :~  :-  'capabilities'
                %-  pairs:enjs:format
                :~  ['tools' (pairs:enjs:format ~[['listChanged' b+|]])]
                    ['resources' (pairs:enjs:format ~[['listChanged' b+|] ['subscribe' b+|]])]
                    ['prompts' (pairs:enjs:format ~[['listChanged' b+|]])]
                ==
                :-  'serverInfo'
                %-  pairs:enjs:format
                :~  ['name' s+(crip "{(trip (scot %p our.bowl))} mcp-proxy")]
                    ['version' s+'1.0.0']
                ==
                ['protocolVersion' s+'2024-11-05']
            ==
        ==
      (give-http eyre-id 200 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html (en:json:html resp))))
    ::
        %'notifications/initialized'
      :_  this
      (give-http eyre-id 200 ~[cors] ~)
    ::
        ?(%'tools/list' %'resources/list' %'prompts/list')
      (fan-out eyre-id req-id method)
    ::
        ?(%'tools/call' %'resources/read' %'prompts/get')
      (route-call eyre-id req u.jon method)
    ==
  ::
  ::  fan out a list request to all enabled servers
  ::
  ++  fan-out
    |=  [eyre-id=@ta req-id=json method=@t]
    ^-  (quip card _this)
    =/  enabled=(list [server-id:mcp-proxy mcp-server:mcp-proxy])
      %+  skim
        %+  turn  server-order
        |=(sid=server-id:mcp-proxy [sid (~(got by servers) sid)])
      |=([* srv=mcp-server:mcp-proxy] enabled.srv)
    ?~  enabled
      ::  no servers: return empty
      =/  key=@t
        ?+  method  'items'
          %'tools/list'      'tools'
          %'resources/list'  'resources'
          %'prompts/list'    'prompts'
        ==
      =/  resp=json
        %-  pairs:enjs:format
        :~  ['jsonrpc' s+'2.0']
            ['id' req-id]
            ['result' (pairs:enjs:format ~[[key a+~]])]
        ==
      :_  this
      (give-http eyre-id 200 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html (en:json:html resp))))
    =/  group-id=@t  (scot %uv `@uv`eny.bowl)
    =/  total=@ud  (lent enabled)
    =.  agg-pending
      (~(put by agg-pending) group-id [eyre-id req-id method total ~])
    ::  build upstream request body
    =/  upstream-body=@t
      %-  en:json:html
      %-  pairs:enjs:format
      :~  ['jsonrpc' s+'2.0']
          ['method' s+method]
          ['id' (numb:enjs:format 1)]
          ['params' (pairs:enjs:format ~)]
      ==
    :_  this
    %+  turn  enabled
    |=  [sid=server-id:mcp-proxy srv=mcp-server:mcp-proxy]
    =/  out-headers=(list [key=@t value=@t])
      %+  weld
        ~[['content-type' 'application/json'] ['accept' 'application/json']]
      headers.srv
    =/  cookie=(unit @t)  (~(get by cookies) sid)
    =?  out-headers  ?=(^ cookie)
      (snoc out-headers ['cookie' u.cookie])
    =/  oauth-hdr=(unit [key=@t value=@t])
      (get-oauth-header oauth-provider.srv our.bowl now.bowl)
    =?  out-headers  ?=(^ oauth-hdr)
      (snoc out-headers u.oauth-hdr)
    :*  %pass  /iris/agg/[group-id]/[sid]
        %arvo  %i  %request
        [%'POST' url.srv out-headers `(as-octs:mimes:html upstream-body)]
        *outbound-config:iris
    ==
  ::
  ::  route a call/read/get to a specific server based on name prefix
  ::
  ++  route-call
    |=  [eyre-id=@ta req=inbound-request:eyre jon=json method=@t]
    ^-  (quip card _this)
    ::  extract the name field from params
    =/  params=json  (get-json-field jon 'params')
    =/  name-key=@t
      ?+  method  'name'
        %'tools/call'     'name'
        %'resources/read'  'uri'
        %'prompts/get'     'name'
      ==
    =/  full-name=@t  (get-json-string params name-key)
    ::  split on first _ to get server-id and real name
    =/  [sid=@t real-name=@t]  (split-on-underscore full-name)
    =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) `@tas`sid)
    ?~  srv
      :_  this
      %-  give-http  :^  eyre-id  404
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"server not found in tool prefix"}'))
    ::  rebuild request with original name
    =/  new-params=json
      ?>  ?=(%o -.params)
      [%o (~(put by p.params) name-key s+real-name)]
    =/  new-body=@t
      %-  en:json:html
      ?>  ?=(%o -.jon)
      [%o (~(put by p.jon) 'params' new-params)]
    ::  forward as proxy request
    =/  out-headers=(list [key=@t value=@t])
      %+  weld
        ~[['content-type' 'application/json'] ['accept' 'application/json']]
      headers.u.srv
    =/  cookie=(unit @t)  (~(get by cookies) `@tas`sid)
    =?  out-headers  ?=(^ cookie)
      (snoc out-headers ['cookie' u.cookie])
    =/  oauth-hdr=(unit [key=@t value=@t])
      (get-oauth-header oauth-provider.u.srv our.bowl now.bowl)
    =?  out-headers  ?=(^ oauth-hdr)
      (snoc out-headers u.oauth-hdr)
    =/  wire-id=@t  (scot %uv `@uv`eny.bowl)
    =.  pending  (~(put by pending) wire-id eyre-id)
    :_  this
    :~  :*  %pass  /iris/proxy/[wire-id]
            %arvo  %i  %request
            [%'POST' url.u.srv out-headers `(as-octs:mimes:html new-body)]
            *outbound-config:iris
        ==
    ==
  ::
  ::  single-server direct proxy (existing behavior)
  ::
  ++  handle-mcp
    |=  [eyre-id=@ta req=inbound-request:eyre site=(list @t)]
    ^-  (quip card _this)
    ?:  =(%'OPTIONS' method.request.req)
      :_  this
      %-  give-http  :^  eyre-id  204
      :~  cors
          ['access-control-allow-methods' 'GET, POST, DELETE, OPTIONS']
          ['access-control-allow-headers' 'Content-Type, Accept, Authorization, Mcp-Session-Id']
          ['access-control-expose-headers' 'Mcp-Session-Id']
          ['access-control-max-age' '86400']
      ==
      ~
    ?~  site
      :_  this
      %-  give-http  :^  eyre-id  400
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"missing server id"}'))
    =/  sid=server-id:mcp-proxy  i.site
    =/  srv=(unit mcp-server:mcp-proxy)  (~(get by servers) sid)
    ?~  srv
      :_  this
      %-  give-http  :^  eyre-id  404
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"server not found"}'))
    ?.  enabled.u.srv
      :_  this
      %-  give-http  :^  eyre-id  503
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"server disabled"}'))
    =/  out-headers=(list [key=@t value=@t])
      %+  weld
        ~[['content-type' 'application/json'] ['accept' 'application/json, text/event-stream']]
      headers.u.srv
    =/  cookie=(unit @t)  (~(get by cookies) sid)
    =?  out-headers  ?=(^ cookie)
      (snoc out-headers ['cookie' u.cookie])
    =/  oauth-hdr=(unit [key=@t value=@t])
      (get-oauth-header oauth-provider.u.srv our.bowl now.bowl)
    =?  out-headers  ?=(^ oauth-hdr)
      (snoc out-headers u.oauth-hdr)
    =/  session-id=(unit @t)
      =/  hdrs=(list [key=@t value=@t])  header-list.request.req
      |-
      ?~  hdrs  ~
      ?:  =(key.i.hdrs 'mcp-session-id')  `value.i.hdrs
      $(hdrs t.hdrs)
    =?  out-headers  ?=(^ session-id)
      (snoc out-headers ['mcp-session-id' u.session-id])
    =/  wire-id=@t  (scot %uv `@uv`eny.bowl)
    =.  pending  (~(put by pending) wire-id eyre-id)
    :_  this
    :~  :*  %pass  /iris/proxy/[wire-id]
            %arvo  %i  %request
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
            :-  'oauthProvider'
            ?~  oauth-provider.srv  ~
            s+(scot %tas u.oauth-provider.srv)
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
    =/  cookie=(unit @t)
      =/  hdrs=(list [key=@t value=@t])  headers.response-header.resp
      |-
      ?~  hdrs  ~
      ?:  =(key.i.hdrs 'set-cookie')
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
    =/  wire-id=@t  i.t.t.wire
    =/  eid=(unit @ta)  (~(get by pending) wire-id)
    ?~  eid
      ~&  [%mcp-proxy %no-pending wire-id]
      `this
    =.  pending  (~(del by pending) wire-id)
    ?.  ?=([%iris %http-response *] sign)
      :_  this
      %-  give-http  :^  u.eid  502
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"unexpected iris response"}'))
    =/  resp=client-response:iris  client-response.sign
    ?.  ?=(%finished -.resp)
      :_  this
      %-  give-http  :^  u.eid  502
      ~[cors ['content-type' 'application/json']]
      (some (as-octs:mimes:html '{"error":"upstream in progress"}'))
    =/  resp-headers=(list [key=@t value=@t])
      %+  weld  ~[cors ['access-control-expose-headers' 'Mcp-Session-Id']]
      %+  skip  headers.response-header.resp
      |=  [key=@t value=@t]
      ?|(=(key 'transfer-encoding') =(key 'connection'))
    =/  bod=(unit octs)
      ?~  full-file.resp  ~
      `data.u.full-file.resp
    :_  this
    =/  =path  /http-response/[u.eid]
    :~  [%give %fact ~[path] %http-response-header !>(`response-header:http`[status-code.response-header.resp resp-headers])]
        [%give %fact ~[path] %http-response-data !>(bod)]
        [%give %kick ~[path] ~]
    ==
  ::
      [%iris %agg @ @ ~]
    ::  aggregate response: /iris/agg/{group-id}/{server-id}
    ::
    =/  group-id=@t  i.t.t.wire
    =/  sid=server-id:mcp-proxy  i.t.t.t.wire
    =/  req=(unit agg-request)  (~(get by agg-pending) group-id)
    ?~  req
      ~&  [%mcp-proxy %agg-no-pending group-id sid]
      `this
    ::  parse the upstream response (handles both plain JSON and SSE format)
    =/  result-json=(unit json)
      ?.  ?=([%iris %http-response *] sign)  ~
      =/  resp=client-response:iris  client-response.sign
      ?.  ?=(%finished -.resp)  ~
      ?.  =(200 status-code.response-header.resp)  ~
      ?~  full-file.resp  ~
      =/  body=@t  `@t`q.data.u.full-file.resp
      ::  strip SSE "data: " prefix if present
      =/  clean=@t  (strip-sse body)
      (de:json:html clean)
    ::  store result (~ if failed, which is ok)
    =/  new-results=(map server-id:mcp-proxy (unit json))
      (~(put by results.u.req) sid result-json)
    =/  received=@ud  ~(wyt by new-results)
    ::  not all in yet: update and wait
    ?.  =(received total.u.req)
      =.  agg-pending
        (~(put by agg-pending) group-id u.req(results new-results))
      `this
    ::  all responses in: combine and respond
    =.  agg-pending  (~(del by agg-pending) group-id)
    =/  result-key=@t
      ?+  method.u.req  'items'
        %'tools/list'      'tools'
        %'resources/list'  'resources'
        %'prompts/list'    'prompts'
      ==
    =/  name-key=@t
      ?+  method.u.req  'name'
        %'tools/list'      'name'
        %'resources/list'  'uri'
        %'prompts/list'    'name'
      ==
    ::  combine items from all servers, prefixing names
    =/  all-items=(list json)
      %-  zing
      %+  turn  ~(tap by new-results)
      |=  [s-id=server-id:mcp-proxy res=(unit json)]
      ?~  res  ~
      =/  result=json  (get-json-field u.res 'result')
      ?.  ?=(%o -.result)  ~
      =/  items-json=(unit json)  (~(get by p.result) result-key)
      ?~  items-json  ~
      ?.  ?=(%a -.u.items-json)  ~
      ::  prefix each item's name with server-id_
      %+  turn  p.u.items-json
      |=  item=json
      ?.  ?=(%o -.item)  item
      =/  orig-name=@t
        =/  n=(unit json)  (~(get by p.item) name-key)
        ?~  n  ''
        ?.  ?=(%s -.u.n)  ''
        p.u.n
      =/  prefixed=@t  (cat 3 (cat 3 (scot %tas s-id) '_') orig-name)
      [%o (~(put by p.item) name-key s+prefixed)]
    ::  build combined response
    =/  resp=json
      %-  pairs:enjs:format
      :~  ['jsonrpc' s+'2.0']
          ['id' req-id.u.req]
          ['result' (pairs:enjs:format ~[[result-key a+all-items]])]
      ==
    :_  this
    (give-http eyre-id.u.req 200 ~[cors ['content-type' 'application/json']] (some (as-octs:mimes:html (en:json:html resp))))
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
++  cors  ['access-control-allow-origin' '*']
::
++  get-optional-tas
  |=  [jon=json key=@t]
  ^-  (unit @tas)
  ?.  ?=(%o -.jon)  ~
  =/  v=(unit json)  (~(get by p.jon) key)
  ?~  v  ~
  ?.  ?=(%s -.u.v)  ~
  ?:  =('' p.u.v)  ~
  ``@tas`p.u.v
::
++  get-oauth-header
  |=  [oauth-prov=(unit @tas) our=@p now=@da]
  ^-  (unit [key=@t value=@t])
  ?~  oauth-prov  ~
  =/  has=?
    =/  res  (mule |.(.^(? %gx /(scot %p our)/oauth/(scot %da now)/has-grant/[u.oauth-prov]/noun)))
    ?:(?=(%& -.res) p.res %.n)
  ?.  has  ~
  =/  gra=(unit grant:oauth)
    =/  res  (mule |.(.^(grant:oauth %gx /(scot %p our)/oauth/(scot %da now)/grant/[u.oauth-prov]/noun)))
    ?:(?=(%& -.res) `p.res ~)
  ?~  gra  ~
  `['authorization' (rap 3 ~[token-type.u.gra ' ' access-token.u.gra])]
::
++  strip-sse
  |=  body=@t
  ^-  @t
  =/  t=tape  (trip body)
  ?.  =("data: " (scag 6 t))  body
  =/  rest=tape  (slag 6 t)
  ::  trim trailing whitespace/newlines by flipping and dropping
  %-  crip  %-  flop
  =/  r=tape  (flop rest)
  |-  ^-  tape
  ?~  r  ~
  ?:  ?|(=(10 i.r) =(13 i.r) =(32 i.r))
    $(r t.r)
  r
::
++  get-base-url
  |=  url=@t
  ^-  @t
  =/  t=tape  (trip url)
  =/  scheme-mark=(unit @ud)  (find "://" t)
  ?~  scheme-mark  url
  =/  after-scheme=@ud  (add 3 u.scheme-mark)
  =/  rest=tape  (slag after-scheme t)
  =/  path-start=(unit @ud)  (find "/" rest)
  ?~  path-start  url
  (crip (scag (add after-scheme u.path-start) t))
::
++  get-json-field
  |=  [jon=json key=@t]
  ^-  json
  ?.  ?=(%o -.jon)  ~
  (fall (~(get by p.jon) key) ~)
::
++  get-json-string
  |=  [jon=json key=@t]
  ^-  @t
  =/  v=json  (get-json-field jon key)
  ?.  ?=(%s -.v)  ''
  p.v
::
++  split-on-underscore
  |=  name=@t
  ^-  [@t @t]
  =/  t=tape  (trip name)
  =/  idx=(unit @ud)  (find "_" t)
  ?~  idx  [name '']
  [(crip (scag u.idx t)) (crip (slag +(u.idx) t))]
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
      :~  id+so  name+so  url+so
          headers+(ar (ot ~[key+so value+so]))
      ==
    =/  [id=@t name=@t url=@t headers=(list header:mcp-proxy)]  (f jon)
    =/  oprov=(unit @tas)  (get-optional-tas jon 'oauth-provider')
    [%add-server `@tas`id [name url headers %.y oprov]]
      %'remove-server'
    [%remove-server `@tas`((ot ~[id+so]) jon)]
      %'update-server'
    =/  f
      %-  ot
      :~  id+so  name+so  url+so
          headers+(ar (ot ~[key+so value+so]))
          enabled+bo
      ==
    =/  [id=@t name=@t url=@t headers=(list header:mcp-proxy) enabled=?]  (f jon)
    =/  oprov=(unit @tas)  (get-optional-tas jon 'oauth-provider')
    [%update-server `@tas`id [name url headers enabled oprov]]
      %'toggle-server'
    [%toggle-server `@tas`((ot ~[id+so]) jon)]
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
      :-  'headers'  :-  %a
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
