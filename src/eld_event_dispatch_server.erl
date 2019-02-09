%%-------------------------------------------------------------------
%% @doc Event dispatch server
%%
%% @end
%%-------------------------------------------------------------------

-module(eld_event_dispatch_server).

-behaviour(gen_server).

%% Supervision
-export([start_link/1, init/1]).

%% Behavior callbacks
-export([code_change/3, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% API
-export([send_events/3]).

-type state() :: #{
    sdk_key => string(),
    events_uri => string()
}.

%%===================================================================
%% API
%%===================================================================

%% @doc Start listening to streaming events
%%
%% @end
-spec send_events(Tag :: atom(), Events :: [eld_event:event()], SummaryEvent :: eld_event_server:summary_event()) ->
    ok.
send_events(Tag, Events, SummaryEvent) ->
    ServerName = get_local_reg_name(Tag),
    gen_server:call(ServerName, {send_events, Events, SummaryEvent}).

%%===================================================================
%% Supervision
%%===================================================================

%% @doc Starts the server
%%
%% @end
-spec start_link(Tag :: atom()) ->
    {ok, Pid :: pid()} | ignore | {error, Reason :: term()}.
start_link(Tag) ->
    ServerName = get_local_reg_name(Tag),
    io:format("Starting events dispatcher with name: ~p~n", [ServerName]),
    gen_server:start_link({local, ServerName}, ?MODULE, [Tag], []).

-spec init(Args :: term()) ->
    {ok, State :: state()} | {ok, State :: state(), timeout() | hibernate} |
    {stop, Reason :: term()} | ignore.
init([Tag]) ->
    SdkKey = eld_settings:get_value(Tag, sdk_key),
    EventsUri = eld_settings:get_value(Tag, events_uri),
    State = #{
        sdk_key => SdkKey,
        events_uri => EventsUri
    },
    {ok, State}.

%%===================================================================
%% Behavior callbacks
%%===================================================================

-type from() :: {pid(), term()}.
-spec handle_call(Request :: term(), From :: from(), State :: state()) ->
    {reply, Reply :: term(), NewState :: state()} |
    {stop, normal, {error, atom(), term()}, state()}.
handle_call({send_events, Events, SummaryEvent}, _From, #{sdk_key := _SdkKey, events_uri := Uri} = State) ->
    {ok, {_Scheme, _UserInfo, _Host, _Port, _Path, _Query}} = http_uri:parse(Uri),
    io:format("Sending events: ~p~n", [Events]),
    io:format("Sending summary event: ~p~n", [SummaryEvent]),
    {reply, ok, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

-spec terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: state()) -> term().
terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%===================================================================
%% Internal functions
%%===================================================================

-spec get_local_reg_name(Tag :: atom()) -> atom().
get_local_reg_name(Tag) ->
    list_to_atom("eld_event_dispatch_server_" ++ atom_to_list(Tag)).
