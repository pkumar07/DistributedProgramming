defmodule Client do
    use GenServer
    
    # API
    def register(name) do
        #case via_tuple(name) do
        #    :error ->
        #      Supervisor.start_child(via_tuple("Supervisor"), [via_tuple(name)]) 
        #    pid ->
        #        {:error, :process_already_registered_start_it}  
        #end
        if via_tuple(name) == :undefined do
            {:ok, pid} = GenServer.start_link(__MODULE__, [name], name: String.to_atom(name))
            :global.register_name(String.to_atom(name), pid)
        else
            {:error, :process_already_registered}
        end
    end
    
    def start_link(name) do
        {:ok, pid} = GenServer.start_link(__MODULE__, [name], name: String.to_atom(name))
        :global.register_name(String.to_atom(name), pid)
        GenServer.call(via_tuple(name), {:load_offline_tweets, name})
    end
    
    def stop(name) do
        try_call name, {:stop}
    end
    
    def subscribe(name, process_name) do
        try_call name, {:subscribe, name, process_name}
    end
    
    def send_tweet(name, tweet) do
        try_cast name, {:send_tweet, name, tweet}
    end
    
    def search_hashtag(name, hash_tag) do
        try_call name, {:search_hashtag, hash_tag}
    end
    
    def search_my_mentions(name) do
        try_call name, {:search_my_mentions, name}
    end
    def get_user_tweets(name) do
        try_call name, {:load_user_tweets, name}
    end
    def get_user_retweets(name) do
        list_user_retweets = try_call name, {:load_user_retweets, name}
        list_user_retweets
    end
    
    def retweet(name, tweet_id) do
        try_cast name, {:retweet, name, tweet_id}
    end
    
    defp try_cast(name, message) do
        case via_tuple(name) do
          :undefined ->
            {:error, :process_not_registered}
          client ->
            GenServer.cast(client, message)
        end
    end
    
    defp try_call(name, message) do
        case via_tuple(name) do
          :undefined ->
            {:error, :process_not_registered}
          client ->
            GenServer.call(client, message)
        end
    end
    
    def via_tuple(name) do
        #{:via, :gproc, {:n, :l, {:tweeter, name}}}
        #{:via, Tweeter.Registry, {:tweeter, name}}
      :global.whereis_name(String.to_atom(name))
    end
    
    # Server Callbacks
    
    def init(name) do
                     
        if :ets.lookup(:Tweeter, "Tweeter") != [] do
            server = String.to_atom(:ets.lookup_element(:Tweeter, "Tweeter", 2))
            # Retrieve the fully qualified client node ip
            {ok, [{ip_comma, gateway,subnet}, {_,_,_}]} = :inet.getif 
            ip = :inet.ntoa(ip_comma)       
            qip = Enum.at(name,0) <> "@" <> to_string(ip)
            #qip = Enum.at(name,0) <> "@" <> "192.168.56.1"
        
            # Start the client node and set cookie
            unless Node.alive?() do
                Node.start(String.to_atom(qip))
            end
        
            Node.set_cookie(Node.self, :"chocolate-chip")
            
            case Node.connect(server) do
                true -> :ok
                reason ->
                    IO.puts "Could not connect to server_ip, reason: #{reason}"
                    System.halt(0)
            end     
        end
        {:ok,name}
    end
    def terminate(reason, state) do
        :global.unregister_name(state)
        #uncomment
        IO.puts "stopped: #{inspect(state)}" 
        :normal
    end
    
    def handle_cast({:send_tweet, name, tweet}, state) do
        #GenServer.cast(via_tuple("Tweeter"), {:send_tweet, name, tweet})
        GenServer.cast(:global.whereis_name(:Tweeter), {:send_tweet, name, tweet})
        {:noreply, state}
    end
    
    def handle_cast({:retweet, name, tweet_id}, state) do
        #GenServer.cast(via_tuple(Tweeter), {:retweet, name, tweet_id})
        GenServer.cast(:global.whereis_name(:Tweeter), {:retweet, name, tweet_id})
        {:noreply, state}
    end
    
    def handle_cast({:display_tweet, sender, tweet, tweet_id}, state) do
        #uncomment
        IO.puts "tweet_id #{inspect tweet_id} tweet: #{inspect tweet} sender: #{inspect sender}"
        {:noreply, state}
    end
    
    def handle_cast({:display_retweet, sender, original_sender, tweet, tweet_id}, state) do
        #uncomment
        IO.puts "RT: tweet_id: #{inspect tweet_id} tweet: #{inspect tweet} sender: #{inspect sender} original_sender: #{inspect original_sender}"
        {:noreply, state}
    end
    def handle_call({:subscribe, name, process_name}, _from, state) do
        #GenServer.cast(via_tuple("Tweeter"), {:subscribe, name, process_name})
        list_subscribed_tweets = GenServer.call(:global.whereis_name(:Tweeter), {:subscribe, name, process_name})
        Enum.each list_subscribed_tweets, fn(x) -> 
            #uncomment
            IO.puts x
        end
        {:reply, :done, state}
    end
    
    def handle_call({:search_hashtag, hash_tag}, _from, state) do
        #list_hashtag_tweets = GenServer.call(via_tuple(Tweeter), {:search_hashtag, name, hash_tag})
        list_hashtag_tweets = GenServer.call(:global.whereis_name(:Tweeter), {:search_hashtag, hash_tag})
        Enum.each list_hashtag_tweets, fn(x) -> 
            #uncomment
            IO.puts x
        end
        {:reply, :done, state}
    end
    
    def handle_call({:search_my_mentions, name}, _from, state) do
        #list_mymention_tweets = GenServer.call(via_tuple(Tweeter), {:search_my_mentions, name})
        list_mymention_tweets = GenServer.call(:global.whereis_name(:Tweeter), {:search_my_mentions, name})
        Enum.each list_mymention_tweets, fn(x) -> 
            #uncomment
            IO.puts x
        end
        {:reply, :done, state}
    end
    def handle_call({:load_offline_tweets, name}, _from, state) do
        #list_user_tweets = GenServer.call(via_tuple("Tweeter"), {:load_tweets, name})
        list_offline_tweets = GenServer.call(:global.whereis_name(:Tweeter), {:load_offline_tweets, name})
        Enum.each list_offline_tweets, fn(x) -> 
            #uncomment
            IO.puts x
        end
        {:reply, :done, state}
    end
    def handle_call({:load_user_tweets, name}, _from, state) do
        #list_user_tweets = GenServer.call(via_tuple("Tweeter"), {:load_tweets, name})
        list_user_tweets = GenServer.call(:global.whereis_name(:Tweeter), {:load_user_tweets, name})
        Enum.each list_user_tweets, fn(x) -> 
           #Uncomment
            IO.puts x
        end
        {:reply, :done, state}
    end
    def handle_call({:load_user_retweets, name}, _from, state) do
        #list_user_tweets = GenServer.call(via_tuple("Tweeter"), {:load_tweets, name})
        list_user_retweets = GenServer.call(:global.whereis_name(:Tweeter), {:load_user_retweets, name})
        {:reply, list_user_retweets, state}
    end
    def handle_call({:stop}, _from, state) do
        {:stop, :normal, :ok, state}
    end
end