%%   The contents of this file are subject to the Mozilla Public License
%%   Version 1.1 (the "License"); you may not use this file except in
%%   compliance with the License. You may obtain a copy of the License at
%%   http://www.mozilla.org/MPL/
%%
%%   Software distributed under the License is distributed on an "AS IS"
%%   basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%%   License for the specific language governing rights and limitations
%%   under the License.
%%
%%   The Original Code is RabbitMQ Coverage.
%%
%%   The Initial Developers of the Original Code are Rabbit Technologies Ltd.
%%
%%   Copyright (C) 2010 Rabbit Technologies Ltd.
%%
%%   All Rights Reserved.
%%
%%   Contributor(s): ______________________________________.
%%

-module(coverage).

-rabbit_boot_step({coverage,
                   [{description, "code coverage"},
                    {mfa,         {?MODULE, start_coverage, []}},
                    {enables,     pre_boot}]}).

-behaviour(application).
-behaviour(supervisor).

-export([start_coverage/0]).
-export([start/2, stop/1]).
-export([init/1]). 

stop(_State) ->
    case application:get_env(coverage, directories) of
        undefined ->
            ok;
        {ok, []} ->
            ok;
        _ ->
            rabbit_misc:report_cover(),
            cover:stop()
    end.

start(normal, []) -> supervisor:start_link(?MODULE, []).

start_coverage() ->
    case application:get_env(coverage, directories) of
        undefined ->
            ok;
        {ok, []} ->
            ok;
        {ok, Directories} ->
            {ok, _} = cover:start([node() | nodes()]),
            lists:foldl(
              fun (Dir, ok) ->
                      case cover:compile_beam_directory(Dir) of
                          {error, _} = Err -> Err;
                          _                -> ok
                      end
              end, ok, Directories)
    end.

init([]) -> 
    {ok, {{one_for_all, 0, 1}, []}}.
