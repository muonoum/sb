-module(glue).
-export([yamerl_decode_file/1, yamerl_decode/1]).
-export([configure_proxy/3, request/4, request/6]).

%% yamerl

yamerl_decode_file(Path) ->
    yamerl:decode_file(Path, [{map_node_format, map}, str_node_as_binary]).

yamerl_decode(Data) ->
    yamerl:decode(Data, [{map_node_format, map}, str_node_as_binary]).

%% httpc

configure_proxy(Host, Port, Exceptions) ->
    Host2 = binary_to_list(Host),
    Exceptions2 = [binary_to_list(H) || H <- Exceptions],
    case httpc:set_options([{proxy, {{Host2, Port}, Exceptions2}}]) of
        ok -> {ok, nil};
        {error, reason} -> {error, reason}
    end.

request(Config, Method, Url, Headers) ->
    Url2 = binary_to_list(Url),
    Headers2 = [{binary_to_list(K), binary_to_list(V)} || {K, V} <- Headers],
    httpc_request(Config, Method, {Url2, Headers2}).

request(Config, Method, Url, Headers, ContentType, Body) ->
    Url2 = binary_to_list(Url),
    Headers2 = [{binary_to_list(K), binary_to_list(V)} || {K, V} <- Headers],
    ContentType2 = binary_to_list(ContentType),
    httpc_request(Config, Method, {Url2, Headers2, ContentType2, Body}).

httpc_request(Config, Method, Request) ->
    {config, Redirect, Certs, Timeout} = Config,
    Options = [{body_format, binary}],
    HttpOptions = [{autoredirect, Redirect}, {ssl, ssl_options(Certs)}, timeout(Timeout)],
    case httpc:request(Method, Request, HttpOptions, Options) of
        {ok, {{_Version, Code, _Status}, Headers, Body}} ->
            Headers2 = [{list_to_binary(string:lowercase(K)),
                list_to_binary(V)} || {K, V} <- Headers],
            {ok, {response, Code, Headers2, Body}};
        {error, Error} -> {error, Error}
    end.

timeout({millis, Millis}) -> {timeout, Millis};
timeout(infinity) -> {timeout, infinity}.

ssl_options(Certs) ->
    Common = [{verify, verify_peer}, {customize_hostname_check, [
        {match_fun, public_key:pkix_verify_hostname_match_fun(https)}
    ]}],
    case Certs of
        none -> [{cacerts, public_key:cacerts_get()} | Common];
        {some, Path} -> [{cacertfile, Path} | Common]
    end.
