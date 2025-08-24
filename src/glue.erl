-module(glue).
-export([merge_maps/2]).
-export([yamerl_decode_file/1, yamerl_decode/1]).

merge_maps(Map1, Map2) ->
    F = fun (_Key,  A, B) when is_map(A) and is_map(B) -> merge_maps(A, B); 
            (_Key, _A, B) -> B
        end,
    maps:merge_with(F,  Map1, Map2).

yamerl_decode_file(Path) ->
    yamerl:decode_file(Path, [{map_node_format, map}, str_node_as_binary]).

yamerl_decode(Data) ->
    yamerl:decode(Data, [{map_node_format, map}, str_node_as_binary]).

