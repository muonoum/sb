-module(glue).
-export([yamerl_decode_file/1, yamerl_decode/1]).

yamerl_decode_file(Path) ->
    yamerl:decode_file(Path, [{map_node_format, map}, str_node_as_binary]).

yamerl_decode(Data) ->
    yamerl:decode(Data, [{map_node_format, map}, str_node_as_binary]).

