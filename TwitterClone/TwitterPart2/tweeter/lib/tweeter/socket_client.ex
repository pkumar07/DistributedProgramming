defmodule Tweeter.SocketClient do
  
  @moduledoc false
  require Logger
  alias Phoenix.Channels.GenSocketClient
  
  @behaviour GenSocketClient
  def register(name) do
    {:ok, pid} = GenSocketClient.start_link(
          __MODULE__,
          Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,
          {"ws://localhost:4000/socket/websocket", name}
        )
    :global.register_name(String.to_atom(name), pid)
  end
  
  def start_link(name) do
    {:ok, pid} = GenSocketClient.start_link(
          __MODULE__,
          Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,
          {"ws://localhost:4000/socket/websocket", name}
        )
    :global.register_name(String.to_atom(name), pid)
    #try_send name, {:register, name}
    try_send name, {:load_offline_tweets, name}
  end
  
  def stop(name) do
      :global.unregister_name(name)
      try_send name,{:disconnect, name} 
      {:stop, :ok}
  end
  
  def via_tuple(name) do
    :global.whereis_name(String.to_atom(name))
  end
  def subscribe(name, process_name) do
    try_send name, {:subscribe, name, process_name}
  end
  def send_tweet(name, tweet) do
    try_send name, {:send_tweet, name, tweet}
  end
  def search_hashtag(name, hash_tag) do
    try_send name, {:search_hashtag, hash_tag}
  end
  def search_my_mentions(name) do
    try_send name, {:search_my_mentions, name}
  end
  def get_user_tweets(name) do
    try_send name, {:load_user_tweets, name}
  end
  def get_user_retweets(name) do
    list_user_retweets = try_send name, {:load_user_retweets, name}
    list_user_retweets
  end
  def retweet(name, tweet_id) do
    try_send name, {:retweet, name, tweet_id}
  end
  defp try_send(name, message) do
    case via_tuple(name) do
      :undefined ->
        {:error, :process_not_registered}
      client ->
        Process.send(client, message, [])
        #GenServer.call(client, message)
    end
  end
  def init(args) do
    {url, name} = args
    #IO.puts "Url is #{inspect url}, name is #{inspect name}"
    {:connect, url, [], %{name: name}}
  end
  def handle_connected(transport, state) do
    Logger.info("connected")
    GenSocketClient.join(transport, "tweeter:#{state.name}")
    {:ok, state}
  end
  def handle_disconnected(reason, state) do
    Logger.error("disconnected: #{inspect reason}")
    #Process.send_after(self(), :connect, :timer.seconds(1))
    {:ok, state}
  end
  def handle_joined(topic, _payload, transport, state) do
    Logger.info("joined the topic #{topic} #{}")
    GenSocketClient.push(transport, topic, "register_user", %{"name" => state.name})
    Logger.info("Registering client #{inspect state.name}")
    #try_send state.name, {:register, state.name}
   
    # if state.first_join do
    #  :timer.send_interval(:timer.seconds(1), self(), :ping_server)
   #   {:ok, %{state | first_join: false, ping_ref: 1}}
   # else
   #   {:ok, %{state | ping_ref: 1}}
   # end
    {:ok,state}
  end
  def handle_join_error(topic, payload, _transport, state) do
    Logger.error("join error on the topic #{topic}: #{inspect payload}")
    {:ok, state}
  end
  def handle_channel_closed(topic, payload, _transport, state) do
    Logger.error("disconnected from the topic #{topic}: #{inspect payload}")
    Process.send_after(self(), {:join, topic}, :timer.seconds(1))
    {:ok, state}
  end
  
  
  # If the server sends an asynchronous message i.e handle_cast
  def handle_message(topic,"display_tweet", %{"response" => map}, _transport, state) do
    IO.puts "came here for topic #{inspect topic}"
    Logger.info("received tweet on topic #{topic}: display_tweet tweet_id: #{inspect Map.get(map, "tweet_id")} tweet: #{inspect Map.get(map, "tweet")} sender: #{inspect Map.get(map, "name")}")
    {:ok, state}
  end
  
  #poornima
  def handle_message(topic,"display_retweet", %{"response" => map}, _transport, state) do
    Logger.info("RT: received tweet on topic #{topic}: display_retweet tweet_id: #{inspect Map.get(map, "tweet_id")} tweet: #{inspect Map.get(map, "tweet")} sender: #{inspect Map.get(map, "name")} original_sender: #{inspect Map.get(map, "original_sender")}")
    {:ok, state}
  end
  def handle_message(topic,"subscribe", %{"response" => list_subscribed_tweets} = map, _transport, state) do
      list_subscribed_tweets = Map.get(map, "response")
      Enum.each list_subscribed_tweets, fn(x) -> 
        #uncomment
        Logger.info("subscribed tweet for #{state.name}: #{x}")
      end
      {:ok, state}
  end
  def handle_message(topic, "search_hashtag", %{"response" => list_hashtag_tweets} = map, _transport, state) do
    list_hashtag_tweets = Map.get(map, "response")
    Enum.each list_hashtag_tweets, fn(x) -> 
      #uncomment
      Logger.info("hashtag tweet for #{state.name}: #{x}")
    end
    {:ok, state}
  end
  def handle_message(topic, "search_my_mentions", %{"response" => list_mymention_tweets} = map, _transport, state) do
    list_mymention_tweets = Map.get(map, "response")
    Enum.each list_mymention_tweets, fn(x) -> 
      #uncomment
      Logger.info("mentioned tweet for #{state.name}: #{x}")
    end
    {:ok, state}
  end
  def handle_message(topic, "load_offline_tweets", %{"response"=> list_offline_tweets} = map, _transport, state) do
    list_offline_tweets = Map.get(map, "response")
    Enum.each list_offline_tweets, fn(x) -> 
      #uncomment
      Logger.info("loaded offline tweet for #{state.name}: #{x}")
    end
    {:ok, state}
  end
  def handle_message(topic, "load_user_tweets", %{"response" => list_user_tweets} = map, _transport, state) do
    list_user_tweets = Map.get(map, "response")
    Enum.each list_user_tweets, fn(x) -> 
      #uncomment
      Logger.info("loaded tweet for #{state.name}: #{x}")
    end
    {:ok, state}
  end
  def handle_message(topic, "load_user_retweets", %{"response" => list_user_retweets} = map, _transport, state) do
    list_user_retweets = Map.get(map, "response")
    {:ok, list_user_retweets, state}
  end
  def handle_message(topic, "register", %{"response" => response} , _transport, state) do
    Logger.info(response)
    {:ok, state}
  end
  def handle_message(topic, "disconnect", %{"response" => response} , _transport, state) do
    Logger.info(response)
    {:ok, state}
  end
  
  
  # If the server-side channel replies directly (using the {:reply, ...})
  def handle_reply("ping", _ref, %{"status": ok} = payload, _transport, state) do
    Logger.info("server pong ##{payload["response"]["ping_ref"]}")
    {:ok, state}
  end
  
  
    
  
  # client process sends are handled here
  # def handle_info({:register, name}, transport, state) do
  #   Logger.info("Registering client #{inspect name}")
  #   GenSocketClient.push(transport, "tweeter:#{state.name}", "register", %{"name" => name, "pid"=> self()})
  #   {:ok, state}
  # end
  
  def handle_info(:connect, _transport, state) do
    Logger.info("connecting")
    {:connect, state}
  end
  
  def handle_info({:disconnect, name}, transport, state) do
    Logger.info("disconnecting client #{inspect name}")
    GenSocketClient.push(transport, "tweeter:#{state.name}", "disconnect", %{"name" => state.name})
    {:ok, state}
  end
  
  def handle_info({:join, topic}, transport, state) do
    Logger.info("joining the topic #{topic}")
    case GenSocketClient.join(transport, topic) do
      {:error, reason} ->
        Logger.error("error joining the topic #{topic}: #{inspect reason}")
        Process.send_after(self(), {:join, topic}, :timer.seconds(1))
      {:ok, _ref} -> :ok
    end
    {:ok, state}
  end
  
  def handle_info(:ping_server, transport, state) do
    Logger.info("sending ping ##{state.ping_ref}")
    GenSocketClient.push(transport, "ping", "ping", %{ping_ref: state.ping_ref})
    {:ok, %{state | ping_ref: state.ping_ref + 1}}
  end
  
  def handle_info({:subscribe, name, process}, transport, state) do
    Logger.info("#{name} subcribing for #{process}")
    #GenSocketClient.join(transport, "tweeter:#{process}")
    GenSocketClient.push(transport, "tweeter:#{state.name}", "subscribe", %{name: name, process: process})
    {:ok, state}
  end
  def handle_info({:load_offline_tweets, name}, transport, state) do
    Logger.info("loading offline tweets for #{state.name}")
    GenSocketClient.push(transport, "tweeter:#{state.name}", "load_offline_tweets", %{name: name})
    {:ok, state}
  end
  def handle_info({:send_tweet, name, tweet}, transport, state) do
    Logger.info("sending tweet for ##{state.name}")
    GenSocketClient.push(transport, "tweeter:#{state.name}", "send_tweet", %{tweet: tweet, name: name})
    {:ok, state}
  end
  def handle_info({:retweet, name, tweet_id}, transport, state) do
    Logger.info("sending tweet for ##{state.name}")
    GenSocketClient.push(transport, "tweeter:#{state.name}", "retweet", %{tweet_id: tweet_id, name: state.name})
    {:ok, state}
  end
  def handle_info({:search_hashtag, hash_tag}, transport, state) do
    Logger.info("searching hashtag #{hash_tag} for ##{state.name}")
    GenSocketClient.push(transport, "tweeter:#{state.name}", "search_hashtag", %{hash_tag: hash_tag, name: state.name})
    {:ok, state}
  end
  def handle_info({:search_my_mentions, mention}, transport, state) do
    Logger.info("searching mentions for #{mention}")
    GenSocketClient.push(transport, "tweeter:#{state.name}", "search_my_mentions", %{mention: mention})
    {:ok, state}
  end
  def handle_info({:load_user_tweets, name}, transport, state) do
    Logger.info("loading user tweets for #{name}")
    GenSocketClient.push(transport, "tweeter:#{state.name}", "load_user_tweets", %{name: state.name})
    {:ok, state}
  end
  def handle_info({:load_user_retweets, name}, transport, state) do
    Logger.info("loading user tweets for #{name}")
    GenSocketClient.push(transport, "tweeter:#{state.name}", "load_user_retweets", %{name: state.name})
    {:ok, state}
  end
  def handle_info({:load_offline_tweets, name}, transport, state) do
    Logger.info("loading user tweets for #{name}")
    GenSocketClient.push(transport, "tweeter:#{state.name}", "load_offline_tweets", %{name: state.name})
    {:ok, state}
  end
end