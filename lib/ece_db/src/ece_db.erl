%%%----------------------------------------------------------------
%%% @author  Tristan Sloughter <tristan.sloughter@gmail.com>
%%% @doc
%%% @end
%%% @copyright 2011 Tristan Sloughter
%%%----------------------------------------------------------------
-module(ece_db).

-behaviour(gen_server).

%% API
-export([start_link/3,
         all/0,
         find/1,
         create/1,
         update/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
-export_type([]).

-define(SERVER, ?MODULE).

-record(state, {db}).

%%%===================================================================
%%% Public Types
%%%===================================================================

%%%===================================================================
%%% API
%%%===================================================================

start_link(Server, Port, DB) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [Server, Port, DB], []).

all() ->
    gen_server:call(?SERVER, all).

find(ID) ->
    gen_server:call(?SERVER, {find, ID}).

create(Doc) ->
    gen_server:call(?SERVER, {create, Doc}).

update(_ID, _JsonDoc) ->
    ok.

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%% @private
init([Server, Port, DB]) ->
    CouchServer = couchbeam:server_connection(Server, Port, "", []),
    {ok, CouchDB} = couchbeam:open_db(CouchServer, DB),

    {ok, #state{db=CouchDB}}.

%% @private
handle_call(all, _From, #state{db=DB}=State) ->
    {ok, AllDocs} = couchbeam:view(DB, {"all", "find"}, []),
    {ok, Results} = couchbeam_view:fetch(AllDocs),
    {[{<<"total_rows">>, _Total},
      {<<"offset">>, _Offset},
      {<<"rows">>, Rows}]} = Results,

    Docs = lists:map(fun({Row}) ->
                             {<<"value">>, {Value}} = lists:keyfind(<<"value">>, 1, Row),
                             Value
                     end, Rows),
    io:format("Docs ~p~n", [Docs]),
    {reply, mochijson2:encode(Docs), State};
handle_call({find, ID}, _From, #state{db=DB}=State) ->
    {ok, View} = couchbeam:view(DB, {"all", "find"}, [{key, list_to_binary(ID)}]),
    {ok, Results} = couchbeam_view:fetch(View),

    {[{<<"total_rows">>, _Total},
      {<<"offset">>, _Offset},
      {<<"rows">>, [{Row}]}]} = Results,

    {<<"value">>, {Doc}} = lists:keyfind(<<"value">>, 1, Row),
    io:format("Docs ~p~n", [Doc]),
    {reply, mochijson2:encode(Doc), State};
handle_call({create, Doc}, _From, #state{db=DB}=State) ->
    {ok, _Doc1} = couchbeam:save_doc(DB, Doc),
    {reply, ok, State}.

%% @private
handle_cast(_Msg, State) ->
    {noreply, State}.

%% @private
handle_info(_Info, State) ->
    {noreply, State}.

%% @private
terminate(_Reason, _State) ->
    ok.

%% @private
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================