%%% Author  : Rudolph van Graan <>
%%% Description :
%%% Created : 25 Jul 2006 by Rudolph van Graan <>

-module(debughelper).

-export([start/0,
         trace/1,
         trace/2]).

start() ->
  dbg:tracer(),
  dbg:p(all,[c,sos,sol]).

trace(ModuleName) ->
  dbg:tpl(ModuleName,[{'_',[],[{message,{return_trace}}]}]).

trace(ModuleName,Function) ->
  dbg:tpl(ModuleName,Function,[{'_',[],[{message,{return_trace}}]}]).
