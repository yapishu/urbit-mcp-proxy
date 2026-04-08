=,  eyre
|%
+$  request-line
  $:  [ext=(unit @ta) site=(list @t)]
      args=(list [key=@t value=@t])
  ==
++  parse-request-line
  |=  url=@t
  ^-  request-line
  (fall (rush url ;~(plug apat:de-purl:html yque:de-purl:html)) [[~ ~] ~])
::
++  json-to-octs
  |=  jon=json
  ^-  octs
  (as-octs:mimes:html (en:json:html jon))
::
++  app
  |%
  ++  give-simple-payload
    |=  [eyre-id=@ta =simple-payload:http]
    ^-  (list card:agent:gall)
    =/  header-cage
      [%http-response-header !>(response-header.simple-payload)]
    =/  data-cage
      [%http-response-data !>(data.simple-payload)]
    :~  [%give %fact ~[/http-response/[eyre-id]] header-cage]
        [%give %fact ~[/http-response/[eyre-id]] data-cage]
        [%give %kick ~[/http-response/[eyre-id]] ~]
    ==
  --
++  gen
  |%
  ++  json-response
    =|  cache=_|
    |=  =json
    ^-  simple-payload:http
    :_  `(json-to-octs json)
    [200 [['content-type' 'application/json'] ?:(cache [['cache-control' 'max-age=86400'] ~] ~)]]
  ::
  ++  not-found
    ^-  simple-payload:http
    [[404 ~] ~]
  ::
  ++  login-redirect
    |=  =request:http
    ^-  simple-payload:http
    =-  [[307 ['location' -]~] ~]
    %^  cat  3
      '/~/login?redirect='
    url.request
  --
--
