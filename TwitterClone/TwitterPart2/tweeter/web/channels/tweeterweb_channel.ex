defmodule TweeterWeb.TweeterWebChannel do
  
  use Phoenix.Channel
  require Logger
  
  def via_tuple(name) do
    #{:via, :gproc, {:n, :l, {:tweeter, name}}}
    #{:via, Tweeter.Registry, {:tweeter, name}}
    Logger.info("name is #{inspect name}")
    :global.sync
    :global.whereis_name(String.to_atom(name))
  end
  
  def join("tweeter:"<> name, _payload, socket) do
   # %{name: process} = socket.assigns[String.to_atom(name)]
    #Process.send_after(self(), :leave_or_crash, :rand.uniform(2000) + 2000)
    {:ok, socket}
  end
  #def handle_info(:leave_or_crash, socket) do
  #  if :rand.uniform(5) == 1 do
  #    Logger.warn("deliberately disconnecting the client")
  #    Process.exit(socket.transport_pid, :kill)
  #    {:noreply, socket}
  #  else
  #    Logger.warn("deliberately leaving the topic")
  #    {:stop, :normal, socket}
  #  end
  #end
  
  def handle_info(_message, socket) do
    {:noreply, socket}
  end
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end
  def handle_in("register_user", %{"name" => name} = payload,  socket) do
    #:ets.insert(:user_details, {user, socket ,true})
    #Logger.info("uffff")
    name = Map.get(payload, "name")
    # pid = Map.get(payload, "pid")
    # #:global.register_name(name, pid)
    :ets.insert(:user_socks, {name, socket, true})
    # Logger.info("seeeeeeeeeeeeeeeeeeeeeee #{inspect :global.whereis_name(name)}")
    push socket, "register", %{"response"=>name<>" registered successfully." }
    {:noreply, socket}
  end
  def handle_in("disconnect", %{"name" => name} = payload,  socket) do
    #:ets.insert(:user_details, {user, socket ,true})
    #Logger.info("uffff")
    name = Map.get(payload, "name")
    # pid = Map.get(payload, "pid")
    # #:global.register_name(name, pid)
    [user_tuple] = :ets.match_object(:user_socks,{name,:"_",:"_"})
    :ets.insert(:user_socks,{elem(user_tuple,0),elem(user_tuple,1),false})
    # Logger.info("seeeeeeeeeeeeeeeeeeeeeee #{inspect :global.whereis_name(name)}")
    push socket, "disconnect", %{"response"=>name<>"disconnected" }
    {:noreply, socket}
  end
  
  def handle_in("subscribe", payload, socket) do
    name = Map.get(payload, "name")
    process_name = Map.get(payload, "process")

    IO.puts "inspecting #{inspect name}, #{inspect process_name}"
    :ets.insert(:subscribers, {process_name, name})
    :ets.insert(:following, {name, process_name})
    list_subscribed_tweets = load_subscribed_tweets(:user_tweets, :tweets, process_name)
    map = %{"response" => list_subscribed_tweets}
    IO.puts "Inspecting map #{inspect map}" 
    push socket, "subscribe", map
    {:noreply, socket}
  end

  def handle_in("send_tweet", payload, socket) do
    tweet = Map.get(payload, "tweet")
    name = Map.get(payload, "name")
    
    if :ets.lookup(:tweet_count, :count) == [] do
        count = 1
        :ets.insert(:tweet_count, {:count, 1})
    else
       count = :ets.lookup_element(:tweet_count, :count, 2) + 1
      :ets.update_element(:tweet_count, :count, {2, count})
    end
    tweet_id = count
    # insert hashtags from tweet 
    list_hashtags = Regex.scan(~r/#[^\s]*/, tweet) |> Enum.concat
    Enum.each list_hashtags, fn(hash_tag) ->
        #IO.puts "Inserting hashtag #{inspect hash_tag} in tweet #{inspect tweet} with tweet_id #{inspect tweet_id} in hashtags"
        :ets.insert(:hashtags, {hash_tag, tweet_id})
    end
    
    # send tweet to connected mentioned processes
    list_my_mentions = Regex.scan(~r/@[^\s]*/, tweet) |> Enum.concat
    Enum.each list_my_mentions, fn(my_mention) ->
      # insert my_mentions from the tweet
      my_mention = String.trim(my_mention, "@")
      :ets.insert(:my_mentions, {my_mention, tweet_id})
      [flag] = Enum.at(:ets.match(:user_socks, {my_mention, :"_", :"$1"}), 0)
      if flag == true do
          #######################Process.send via_tuple(my_mention), {:display_tweet, name, tweet, tweet_id})
          #broadcast "tweeter:"<>my_mention, "display_tweet", %{name: name, tweet: tweet, tweet_id: tweet_id}
          [socket2]=Enum.at(:ets.match(:user_socks,{my_mention,:"$1",:"_"}),0)
          push socket2, "display_tweet", %{"response" => %{"name" => name, "tweet" => tweet, "tweet_id" => tweet_id}}
      else
        #insert/update tweet_id in users_offline_tweets for offline mentioned process
        if :ets.lookup(:users_offline_tweets, my_mention) != [] do
            offline_list_temp = :ets.lookup_element(:users_offline_tweets, my_mention, 2)
            :ets.update_element(:users_offline_tweets, my_mention, {2, List.flatten(offline_list_temp ++ [tweet_id])})
        else
            :ets.insert(:users_offline_tweets, {my_mention, [tweet_id]})
        end
      end
    end
    
    # insert the tweet in tweets table
    :ets.insert_new(:tweets, {tweet_id, [name, tweet, 0]})
    
    # insert/update the tweet in user_tweets table
    case :ets.lookup(:user_tweets, name) do
      [{name,_}] ->
        tweets_list = :ets.lookup_element(:user_tweets, name, 2)
        :ets.update_element(:user_tweets, name, {2, List.flatten(tweets_list ++ [tweet_id])})
      [] ->
        #IO.puts "Insert new tweet in user_tweets from client #{inspect name} with #{inspect tweet_id}"
        :ets.insert_new(:user_tweets, {name, [tweet_id]})
    end
       
    #Logger.info("hereeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee #{inspect :ets.lookup(:subscribers, name)}")
    # send/insert tweet to connected subscribers
    if :ets.lookup(:subscribers, name) != [] do
      # send tweet to connected subscribers
      list_subscribers = :ets.lookup_element(:subscribers, name, 2)
      Enum.each list_subscribers, fn (x) ->
        [flag] = Enum.at(:ets.match(:user_socks, {x, :"_", :"$1"}), 0)
        if flag == true do
            #######################Process.send via_tuple(my_mention), {:display_tweet, name, tweet, tweet_id})
            #broadcast "tweeter:"<>my_mention, "display_tweet", %{name: name, tweet: tweet, tweet_id: tweet_id}
            [socket2] = Enum.at(:ets.match(:user_socks,{x,:"$1",:"_"}),0)
            push socket2, "display_tweet", %{"response" => %{"name" => name, "tweet" => tweet, "tweet_id" => tweet_id}}
        else
          Logger.info("else #{inspect list_subscribers} #{inspect via_tuple(x)}")
          if :ets.lookup(:users_offline_tweets, x) != [] do
            offline_list_temp = :ets.lookup_element(:users_offline_tweets, x, 2)
            :ets.update_element(:users_offline_tweets, x, {2, List.flatten(offline_list_temp ++ [tweet_id])})
          else
            :ets.insert(:users_offline_tweets, {x, [tweet_id]})
          end
        end
      end
    end    
    {:noreply, socket}
  end
  
  def handle_in("retweet", payload, socket) do
    name = Map.get(payload, "name")
    tweet_id = Map.get(payload, "tweet_id")
    # insert/update the tweet in user_tweets table
    case :ets.lookup(:user_tweets, name) do
      [{name,_}] ->
          tweets_list = :ets.lookup_element(:user_tweets, name, 2)
          :ets.update_element(:user_tweets, name, {2, List.flatten(tweets_list ++ [tweet_id])})
      [] ->
          :ets.insert_new(:user_tweets, {name, [tweet_id]})
    end
    
    retweet_count = Enum.at(:ets.lookup_element(:tweets, tweet_id, 2), 2)
    list_tweet_details = :ets.lookup_element(:tweets, tweet_id, 2)
    sender = name
    original_sender = Enum.at(list_tweet_details, 0)
    tweet = Enum.at(list_tweet_details, 1)
    :ets.update_element(:tweets, tweet_id, {2, [sender, tweet, retweet_count + 1]})
    if :ets.lookup(:subscribers, name) != [] do
      # send tweet to connected subscribers
      list_subscribers = :ets.lookup_element(:subscribers, name, 2)
      Enum.each list_subscribers, fn (x) ->
        #if via_tuple(x) != :undefined do
          ###################Process.send via_tuple(x), {:display_retweet, sender, original_sender, tweet, tweet_id})                
          #broadcast "tweeter:"<>x, "display_retweet", %{sender: sender, original_sender: original_sender, tweet: tweet, tweet_id: tweet_id}
        [flag] = Enum.at(:ets.match(:user_socks, {x, :"_", :"$1"}), 0)
        if flag == true do
              #######################Process.send via_tuple(my_mention), {:display_tweet, name, tweet, tweet_id})
              #broadcast "tweeter:"<>my_mention, "display_tweet", %{name: name, tweet: tweet, tweet_id: tweet_id}
              [socket2] = Enum.at(:ets.match(:user_socks,{x,:"$1",:"_"}),0)
              push socket2, "display_retweet", %{"response" => %{"sender" => sender, "original_sender" => original_sender, "tweet" => tweet, "tweet_id" => tweet_id}}
          
        else
          if :ets.lookup(:users_offline_tweets, x) != [] do
            offline_list_temp = :ets.lookup_element(:users_offline_tweets, x, 2)
            :ets.update_element(:users_offline_tweets, x, {2, List.flatten(offline_list_temp ++ [tweet_id])})
          else
            :ets.insert(:users_offline_tweets, {x, [tweet_id]})
          end
        end
      end
    end
    {:noreply, socket}
  end
  def handle_in("search_hashtag", payload, socket) do
    hash_tag = Map.get(payload, "hash_tag")
    name = Map.get(payload, "name")
    list_hashtag_tweets = []
    if :ets.lookup(:hashtags, hash_tag) != [] do
        list_tweets = :ets.lookup_element(:hashtags, hash_tag, 2)
        list_hashtag_tweets = get_list_tweets(list_tweets, :tweets, list_hashtag_tweets, 0)
    end
    push socket, "search_hashtag", %{"response" => list_hashtag_tweets}
    {:noreply, socket}
  end
  def handle_in("search_my_mentions", payload, socket) do
    name = Map.get(payload, "mention")
    list_mymention_tweets = []
    if :ets.lookup(:my_mentions, name) != [] do
      list_tweets = :ets.lookup_element(:my_mentions, name, 2)
      list_mymention_tweets = get_list_tweets(list_tweets, :tweets, list_mymention_tweets, 0)
    end
    push socket, "search_my_mentions", %{"response" => list_mymention_tweets}
    {:noreply, socket}
  end
  def handle_in("load_offline_tweets", payload, socket) do
    name = Map.get(payload, "name")
    list_user_tweets = []
    if :ets.lookup(:users_offline_tweets, name) != [] do
      list_tweets = :ets.lookup_element(:users_offline_tweets, name, 2)
      list_user_tweets = get_list_tweets(list_tweets, :tweets, list_user_tweets, 0)
    end
    push socket, "load_offline_tweets", %{"response" => list_user_tweets}
    {:noreply, socket}
  end
  def handle_in("load_user_tweets", payload, socket) do
    name = Map.get(payload, "name")
    list_received_tweets = []
    if :ets.lookup(:following, name) != [] do
       list_following = :ets.lookup_element(:following, name, 2)
       list_received_tweets = get_received_tweets(:user_tweets, :tweets,  list_following, list_received_tweets, 0) 
    else
        []
    end
    push socket, "load_user_tweets", %{"response" => list_received_tweets}
    {:noreply, socket}
  end
  def handle_in("load_user_retweets", payload, socket) do
    name = Map.get(payload, "name")
    list_received_tweets = []
    if :ets.lookup(:following, name) != [] do
       # get list of following processes  
       list_following = :ets.lookup_element(:following, name, 2)
       list_received_tweets = get_received_tweets_ids(:user_tweets, :tweets,  list_following, list_received_tweets, 0) 
       #IO.puts "here #{inspect list_received_tweets}"
    else
        []
    end
    push socket, "load_user_retweets", %{"response" => list_received_tweets}
    {:noreply, socket}
  end
def get_received_tweets(user_tweets,tweets, list_following, list_received_tweets, i) when i == length(list_following) do
    list_received_tweets
end
defp load_subscribed_tweets(user_tweets, tweets, subscribed) do
  list_tweets = []
  list_subscribed_tweets = []
  if :ets.lookup(:user_tweets, subscribed) != [] do
     list_tweets = :ets.lookup_element(:user_tweets, subscribed, 2) 
     list_subscribed_tweets = get_list_tweets(list_tweets, tweets, list_subscribed_tweets, 0)
     list_subscribed_tweets
  else
      []
  end
end
def get_received_tweets(user_tweets,tweets, list_following, list_received_tweets, i) when i < length(list_following) do
    # for each following process
        following = Enum.at(list_following, i)
        # if following process has tweets 
        if :ets.lookup(:user_tweets, following) != [] do
            list_tweets = []
            # get list of tweet_ids of each following process
            list_following_tweets = :ets.lookup_element(:user_tweets, following, 2)
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
        if :ets.lookup(:user_tweets, following) != [] do
            list_tweets = []
            # get list of tweet_ids of each following process
            list_following_tweets = :ets.lookup_element(:user_tweets, following, 2)   
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