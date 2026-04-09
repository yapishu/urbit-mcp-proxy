/-  mcp-proxy
|_  act=action:mcp-proxy
++  grow
  |%
  ++  noun  act
  --
++  grab
  |%
  ++  noun  action:mcp-proxy
  ++  json
    |=  jon=^json
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
      =/  oprov=(unit @tas)
        =/  v=(unit ^json)
          ?.  ?=(%o -.jon)  ~
          (~(get by p.jon) 'oauth-provider')
        ?~  v  ~
        ?.  ?=(%s -.u.v)  ~
        ?:  =('' p.u.v)  ~
        ``@tas`p.u.v
      [%add-server `@tas`id [name url headers %.y oprov]]
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
      =/  oprov=(unit @tas)
        =/  v=(unit ^json)
          ?.  ?=(%o -.jon)  ~
          (~(get by p.jon) 'oauth-provider')
        ?~  v  ~
        ?.  ?=(%s -.u.v)  ~
        ?:  =('' p.u.v)  ~
        ``@tas`p.u.v
      [%update-server `@tas`id [name url headers enabled oprov]]
    ::
        %'toggle-server'
      [%toggle-server `@tas`((ot ~[id+so]) jon)]
    ::
        %'login-server'
      [%login-server `@tas`((ot ~[id+so]) jon)]
    ==
  --
++  grad  %noun
--
