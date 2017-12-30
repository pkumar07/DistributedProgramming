defmodule Tweeter do
    
    use GenServer
        # API
        
        def start_link(name) do
            #store key: tweet_id, value: [tweet, hashtags, mentions, sender]    
            tweets = :ets.new(:tweets, [:ordered_set, :named_table, :public, read_concurrency: true, 
            write_concurrency: false])
            
            #store key: Subscribed To process, value: Subscribed From process 
            subscribers = :ets.new(:subscribers, [:bag, :named_table, :public, read_concurrency: true, 
            write_concurrency: false])
            #store key: Subscribed To process, value: Subscribed From process 
            following = :ets.new(:following, [:bag, :named_table, :public, read_concurrency: true, 
            write_concurrency: false])
    
            #store key: hashtag, value: tweet_id    
            hashtags = :ets.new(:hashtags, [:bag, :named_table, :public, read_concurrency: true, 
            write_concurrency: false])
    
            #store key: mentioned_process_name, value: tweet_id    
            my_mentions = :ets.new(:my_mentions, [:bag, :named_table, :public, read_concurrency: true, 
            write_concurrency: false])
            
            #store key: process name, value: [sent tweet_ids]    
            user_tweets = :ets.new(:user_tweets, [:set, :named_table, :public, read_concurrency: true, 
            write_concurrency: false])
            
            #store key: process name, value: [received offline tweet_ids]
            users_offline_tweets = :ets.new(:users_offline_tweets, [:set, :named_table, :public, read_concurrency: true, 
            write_concurrency: false])
            count = 0  
            {:ok, pid} = GenServer.start_link(__MODULE__, {subscribers,following,tweets,hashtags,my_mentions,user_tweets, users_offline_tweets,count}, name: String.to_atom(name))
            :global.register_name(String.to_atom(name), pid)
        end
        
        def via_tuple(name) do
            #{:via, :gproc, {:n, :l, {:tweeter, name}}}
            #{:via, Tweeter.Registry, {:tweeter, name}}
            :global.whereis_name(String.to_atom(name))
        end
    
        # Server Callbacks
        def init(args) do
           {subscribers,following, tweets,hashtags,my_mentions,user_tweets, users_offline_tweets,count} = args            
          
            # Retrieve the fully qualified client node ip
            {ok, [{ip_comma, gateway,subnet}, {_,_,_}]} = :inet.getif 
            ip = :inet.ntoa(ip_comma)       
            qip = "Tweeter" <> "@" <> to_string(ip)
            #qip = "Tweeter" <> "@" <> "192.168.56.1"
            :ets.new(:Tweeter, [:set, :named_table, :public, read_concurrency: true] )
            :ets.insert(:Tweeter, {"Tweeter", qip})
            # Start the Tweeter node and set cookie
            unless Node.alive?() do
                Node.start(String.to_atom(qip))
            end
            
            Node.set_cookie(Node.self, :"chocolate-chip")
         
            {:ok, {subscribers, following, tweets, hashtags, my_mentions, user_tweets, users_offline_tweets,count}}
        end
          
        def handle_call({:subscribe, name, process_name}, _from, state) do
            {subscribers,following,tweets,hashtags,my_mentions,user_tweets,users_offline_tweets, count} = state
            :ets.insert(subscribers, {process_name, name})
            :ets.insert(following, {name, process_name})
            list_subscribed_tweets = load_subscribed_tweets(user_tweets, tweets, process_name)
            {:reply, list_subscribed_tweets, {subscribers,following,tweets,hashtags,my_mentions,user_tweets, users_offline_tweets,count}}
        end
        defp load_subscribed_tweets(user_tweets, tweets, subscribed) do
            list_tweets = []
            list_subscribed_tweets = []
            if :ets.lookup(user_tweets, subscribed) != [] do
               list_tweets = :ets.lookup_element(user_tweets, subscribed, 2) 
               list_subscribed_tweets = get_list_tweets(list_tweets, tweets, list_subscribed_tweets, 0)
               list_subscribed_tweets
            else
                []
            end
        end
    
        def handle_cast({:send_tweet, name, tweet}, state) do
            {subscribers,following, tweets, hashtags, my_mentions, user_tweets, users_offline_tweets,count} = state
            
            tweet_id = count + 1
            
            # insert hashtags from tweet 
            list_hashtags = Regex.scan(~r/#[^\s]*/, tweet) |> Enum.concat
            Enum.each list_hashtags, fn(hash_tag) ->
                #IO.puts "Inserting hashtag #{inspect hash_tag} in tweet #{inspect tweet} with tweet_id #{inspect tweet_id} in hashtags"
                if :ets.lookup(hashtags, hash_tag) != [] do
                    #IO.puts "#grrrrrrrrr #{inspect :ets.lookup_element(hashtags, hash_tag, 2)}"
                end
                :ets.insert(hashtags, {hash_tag, tweet_id})
            end
            
            # send tweet to connected mentioned processes
            list_my_mentions = Regex.scan(~r/@[^\s]*/, tweet) |> Enum.concat
            Enum.each list_my_mentions, fn(my_mention) ->
                # insert my_mentions from the tweet
                my_mention = String.trim(my_mention, "@")
                if :ets.lookup(my_mentions, my_mention) != [] do
                    #IO.puts "#grrrrrrrrr #{inspect :ets.lookup_element(my_mentions, my_mention, 2)}"
                end
                :ets.insert(my_mentions, {my_mention, tweet_id})
                if via_tuple(my_mention) != :undefined do
                   GenServer.cast(via_tuple(my_mention), {:display_tweet, name, tweet, tweet_id})
                else
                    #insert/update tweet_id in users_offline_tweets for offline mentioned process
                    if :ets.lookup(users_offline_tweets, my_mention) != [] do
                        offline_list_temp = :ets.lookup_element(users_offline_tweets, my_mention, 2)
                        :ets.update_element(users_offline_tweets, my_mention, {2, List.flatten(offline_list_temp ++ [tweet_id])})
                    else
                        :ets.insert(users_offline_tweets, {my_mention, [tweet_id]})
                    end
                end
            end
            
            # insert the tweet in tweets table
            :ets.insert_new(tweets, {tweet_id, [name, tweet, 0]})
    
            # insert/update the tweet in user_tweets table
            case :ets.lookup(user_tweets, name) do
              [{name,_}] ->
                  tweets_list = :ets.lookup_element(user_tweets, name, 2)
                  :ets.update_element(user_tweets, name, {2, List.flatten(tweets_list ++ [tweet_id])})
              [] ->
                  #IO.puts "Insert new tweet in user_tweets from client #{inspect name} with #{inspect tweet_id}"
                  :ets.insert_new(user_tweets, {name, [tweet_id]})
            end
            
            # send/insert tweet to connected subscribers
            if :ets.lookup(subscribers, name) != [] do
                # send tweet to connected subscribers
                list_subscribers = :ets.lookup_element(subscribers, name, 2)
                Enum.each list_subscribers, fn (x) ->
                    if via_tuple(x) != :undefined do
                        GenServer.cast(via_tuple(x), {:display_tweet, name, tweet, tweet_id})
                    else
                        if :ets.lookup(users_offline_tweets, x) != [] do
                            offline_list_temp = :ets.lookup_element(users_offline_tweets, x, 2)
                            :ets.update_element(users_offline_tweets, x, {2, List.flatten(offline_list_temp ++ [tweet_id])})
                        else
                            :ets.insert(users_offline_tweets, {x, [tweet_id]})
                        end
                    end
                end
            end
            
            {:noreply, {subscribers,following,tweets,hashtags,my_mentions,user_tweets, users_offline_tweets,count+1}}
        end
    
        def handle_cast({:retweet, name, tweet_id}, state) do
          {subscribers, following,tweets, hashtags, my_mentions, user_tweets, users_offline_tweets,count} = state
            # insert/update the tweet in user_tweets table
            case :ets.lookup(user_tweets, name) do
              [{name,_}] ->
                  tweets_list = :ets.lookup_element(user_tweets, name, 2)
                  :ets.update_element(user_tweets, name, {2, List.flatten(tweets_list ++ [tweet_id])})
              [] ->
                  :ets.insert_new(user_tweets, {name, [tweet_id]})
            end
            
            retweet_count = Enum.at(:ets.lookup_element(tweets, tweet_id, 2), 2)
            list_tweet_details = :ets.lookup_element(tweets, tweet_id, 2)
            sender = name
            original_sender = Enum.at(list_tweet_details, 0)
            tweet = Enum.at(list_tweet_details, 1)
            :ets.update_element(tweets, tweet_id, {2, [sender, tweet, retweet_count + 1]})
            if :ets.lookup(subscribers, name) != [] do
                # send tweet to connected subscribers
                list_subscribers = :ets.lookup_element(subscribers, name, 2)
                Enum.each list_subscribers, fn (x) ->
                    if via_tuple(x) != :undefined do
                        GenServer.cast(via_tuple(x), {:display_retweet, sender, original_sender, tweet, tweet_id})
                        
                    else
                        if :ets.lookup(users_offline_tweets, x) != [] do
                            offline_list_temp = :ets.lookup_element(users_offline_tweets, x, 2)
                            :ets.update_element(users_offline_tweets, x, {2, List.flatten(offline_list_temp ++ [tweet_id])})
                        else
                            :ets.insert(users_offline_tweets, {x, [tweet_id]})
                        end
                    end
                end
            end
            {:noreply, {subscribers,following,tweets,hashtags,my_mentions,user_tweets, users_offline_tweets,count}}
        end
    
        def handle_call({:search_hashtag, hash_tag}, _from, state) do
            {subscribers,following, tweets, hashtags, my_mentions, user_tweets, users_offline_tweets,count} = state
            list_hashtag_tweets = []
            if :ets.lookup(hashtags, hash_tag) != [] do
                list_tweets = :ets.lookup_element(hashtags, hash_tag, 2)
                list_hashtag_tweets = get_list_tweets(list_tweets, tweets, list_hashtag_tweets, 0)
            end
            {:reply, list_hashtag_tweets, {subscribers,following,tweets,hashtags,my_mentions,user_tweets, users_offline_tweets,count}}
        end
    
        def handle_call({:search_my_mentions, name}, _from, state) do
          {subscribers, following,tweets, hashtags, my_mentions, user_tweets, users_offline_tweets,count} = state
          list_mymention_tweets = []
          if :ets.lookup(my_mentions, name) != [] do
            list_tweets = :ets.lookup_element(my_mentions, name, 2)
            list_mymention_tweets = get_list_tweets(list_tweets, tweets, list_mymention_tweets, 0)
          end                
          {:reply, list_mymention_tweets, {subscribers,following,tweets,hashtags,my_mentions,user_tweets, users_offline_tweets,count}}
        end
        
        def handle_call({:load_offline_tweets, name}, _from, state) do
          {subscribers, following,tweets, hashtags, my_mentions, user_tweets, users_offline_tweets, count} = state
          list_user_tweets = []
          if :ets.lookup(users_offline_tweets, name) != [] do
            list_tweets = :ets.lookup_element(users_offline_tweets, name, 2)
            list_user_tweets = get_list_tweets(list_tweets, tweets, list_user_tweets, 0)
          end
          {:reply, list_user_tweets, {subscribers,following,tweets,hashtags,my_mentions,user_tweets,users_offline_tweets, count}}
        end
        def handle_call({:load_user_tweets, name}, _from, state) do
            {subscribers, following, tweets, hashtags, my_mentions, user_tweets, users_offline_tweets, count} = state
            list_received_tweets = []
            if :ets.lookup(following, name) != [] do
               list_following = :ets.lookup_element(following, name, 2)
               list_received_tweets = get_received_tweets(user_tweets, tweets,  list_following, list_received_tweets, 0) 
            else
                []
            end
            {:reply, list_received_tweets, {subscribers,following,tweets,hashtags,my_mentions,user_tweets,users_offline_tweets, count}}
        end
        def handle_call({:load_user_retweets, name}, _from, state) do
            {subscribers, following, tweets, hashtags, my_mentions, user_tweets, users_offline_tweets, count} = state
            list_received_tweets = []
            if :ets.lookup(following, name) != [] do
               # get list of following processes  
               list_following = :ets.lookup_element(following, name, 2)
               list_received_tweets = get_received_tweets_ids(user_tweets, tweets,  list_following, list_received_tweets, 0) 
               #IO.puts "here #{inspect list_received_tweets}"
            else
                []
            end
            {:reply, list_received_tweets, {subscribers,following,tweets,hashtags,my_mentions,user_tweets,users_offline_tweets, count}}
        end
        def get_received_tweets(user_tweets,tweets, list_following, list_received_tweets, i) when i == length(list_following) do
            list_received_tweets
        end
        def get_received_tweets(user_tweets,tweets, list_following, list_received_tweets, i) when i < length(list_following) do
            # for each following process
                following = Enum.at(list_following, i)
                # if following process has tweets 
                if :ets.lookup(user_tweets, following) != [] do
                    list_tweets = []
                    # get list of tweet_ids of each following process
                    list_following_tweets = :ets.lookup_element(user_tweets, following, 2)
                    # get list of tweets of each following process from list of tweet_ids
                    list_tweets = get_list_tweets(list_following_tweets, tweets, list_tweets, 0)   
                    # append the list of tweets from each following process tweets
                    list_received_tweets = List.flatten(list_received_tweets ++ [list_tweets])
                end
                i = i + 1
                get_received_tweets(user_tweets,tweets, list_following, list_received_tweets, i)
        end
        def get_received_tweets_ids(user_tweets,tweets, list_following, list_received_tweets, i) when i == length(list_following) do
            #IO.puts "huh #{inspect list_received_tweets}"
            list_received_tweets
        end
        def get_received_tweets_ids(user_tweets,tweets, list_following, list_received_tweets, i) when i < length(list_following) do
            # for each following process
             #IO.puts "#{inspect list_following}"
            
                following = Enum.at(list_following, i)
                # if following process has tweets 
                if :ets.lookup(user_tweets, following) != [] do
                    list_tweets = []
                    # get list of tweet_ids of each following process
                    list_following_tweets = :ets.lookup_element(user_tweets, following, 2)   
                    #IO.puts "#{inspect list_received_tweets} #{inspect list_following_tweets}"
                    # append the list of tweets_ids from each following process tweets
                    list_received_tweets = List.flatten(list_received_tweets ++ [list_following_tweets])
                    #IO.puts "#{inspect list_received_tweets}"
                end
                i = i + 1
                get_received_tweets_ids(user_tweets,tweets, list_following, list_received_tweets, i)
            end
        defp get_list_tweets(list, tweets, list_tweets, i) when i == length(list) do
            list_tweets
        end
        defp get_list_tweets(list, tweets, list_tweets, i) when i < length(list) do
                x = Enum.at(list, i)
                string =  "tweet_id: #{inspect x} tweet: #{inspect Enum.at(:ets.lookup_element(tweets, x, 2), 1)} sender: #{inspect Enum.at(:ets.lookup_element(tweets, x, 2), 0)} retweet_count: #{inspect Enum.at(:ets.lookup_element(tweets, x, 2), 2)}"
                list_tweets = List.flatten(list_tweets ++ [string])
                i = i + 1
                get_list_tweets(list, tweets, list_tweets, i)
        end
  end