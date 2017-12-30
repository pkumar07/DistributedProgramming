defmodule Project4Part1Simulator do
    defp get_tweet(no_of_clients) do
        tweets_dictionary = [
            "#food #myLove #IamBukka This is my tweet.",
            "#kids #Chocolate #Dogs #food #can'tStopThinkingAboutFood #IamBukka.",
            "#Iamgreat #BrainIsSaturated #StopThis #Food #Bored I am the best",
            "#gator #florida #sunshineState",
            "This is my #message #NewHashTag #Mumbai"
        ]
        tweets_dictionary = Enum.map(tweets_dictionary, fn(x) ->
            client_no = :rand.uniform(no_of_clients)
            x <> " @Client" <> to_string(client_no)
          end
        )
        Enum.at(tweets_dictionary, :rand.uniform(length(tweets_dictionary)-1))
    end
    
    
    def get_tweet_count(no_of_clients, no_of_tweets, start_time, end_time) when end_time - start_time > 1000  do
        no_of_tweets
    end
    def get_tweet_count(no_of_clients, no_of_tweets, start_time, end_time) when end_time - start_time <= 1000  do
        Client.send_tweet("Client1", "#DOS #Project #testing")
        no_of_tweets = no_of_tweets + 1
        end_time = :os.system_time(:millisecond)
        get_tweet_count(no_of_clients, no_of_tweets, start_time, end_time)
    end
    def retweet_messages(no_of_clients, retweet_count) when retweet_count == 0 do
    end
    
    def retweet_messages(no_of_clients, retweet_count) when retweet_count > 0 do
        client_no = :rand.uniform(no_of_clients)
        process_name = "Client" <> to_string(client_no)
        if(:global.whereis_name(String.to_atom(process_name)) != :undefined) do
            retweets_list = Client.get_user_retweets(process_name)
            if retweets_list != [] do
                Client.retweet(process_name, Enum.random(retweets_list)) 
                retweet_count = retweet_count - 1
            end
        end
        retweet_messages(no_of_clients, retweet_count)
    end
    
    def restart_disconnected_clients(clients_disconnected_list) do
        Enum.each(clients_disconnected_list, 
            fn(x) ->
                process_name = "Client" <> to_string(x)
                if(:global.whereis_name(String.to_atom(process_name)) == :undefined) do
                    Client.start_link(process_name)
                end
            end
        )
    end
    def send_tweets_by_random_clients(no_of_clients, total_tweets_to_send) when total_tweets_to_send > 0 do
        process_name = "Client" <> to_string(:rand.uniform(no_of_clients))
        if(:global.whereis_name(String.to_atom(process_name)) != :undefined) do
            Client.send_tweet(process_name, GenerateTweet.make_tweet(no_of_clients))
            total_tweets_to_send = total_tweets_to_send - 1
        end
    end
    
    def disconnect_clients(clients_disconnected_list) do
        #IO.puts "Clients to be disconnected are #{inspect clients_disconnected_list}"
        Enum.each(clients_disconnected_list, 
            fn(x) ->
                process_name = "Client" <> to_string(x)
                if(:global.whereis_name(String.to_atom(process_name)) != :undefined) do
                    Client.stop(process_name)
                end
            end
        )
    end
    
    def send_tweets(no_of_clients) do
        tweets_per_ms = 0
        for i <- 1..no_of_clients do
            if i == 1 do
                no_of_tweets = (round((no_of_clients/ i)) - 1) * 5
            else
                no_of_tweets = (round((no_of_clients/ i)) ) * 5
            end
            
            #IO.puts "No of tweets = #{inspect no_of_tweets} for client #{inspect i}"
            start_time = :os.system_time(:millisecond)
            for tweet_count <- 1..no_of_tweets do
                process_name = "Client" <> to_string(i)
                if(:global.whereis_name(String.to_atom(process_name)) != :undefined) do
                    Client.send_tweet(process_name, GenerateTweet.make_tweet(no_of_clients))
                    #Client.send_tweet(process_name, get_tweet(no_of_clients))
                end
            end
            end_time = :os.system_time(:millisecond)
            time = end_time - start_time
            
            if time != 0 do
                tweets_per_ms = tweets_per_ms + round(no_of_tweets/time)
                #IO.puts "#{inspect no_of_tweets} tweets sent in #{inspect time} ms"
            end
            
            #IO.puts "Tweets per ms: #{inspect tweets_per_ms} for #{inspect i} client(s)"
        end
    end
    
    def send_tweets_clientlist(no_of_clients, clients_sending_tweets_list) do
        #sends one tweet for every client in the list
        Enum.each(clients_sending_tweets_list, 
            fn(x) ->
                process_name = "Client" <> to_string(x)
                if(:global.whereis_name(String.to_atom(process_name)) != :undefined) do
                    Client.send_tweet(process_name, GenerateTweet.make_tweet(no_of_clients))
                end
            end
        )
    end
    def register_clients(no_of_clients) do
        for i <- 1..no_of_clients do
            process_name = "Client" <> to_string(i)
            if(:global.whereis_name(String.to_atom(process_name)) == :undefined) do
                Client.register(process_name)
            end
        end
    end
    
    def subscribe_clients(no_of_clients) do
        Enum.each(1..no_of_clients, 
            fn(m) ->
                process_name = "Client" <> to_string(m)
                if(:global.whereis_name(String.to_atom(process_name)) != :undefined) do
                    if m == 1 do
                        subscribe_to_count = round((no_of_clients/ m)) - 1
                    else
                        subscribe_to_count = round((no_of_clients/ m))
                    end
                    #subscribe_to_count = round(Float.floor(total_subscribers/(no_of_clients - m + 1))) - 1
                    #IO.puts "Subscriber no #{inspect subscribe_to_count}, for Client #{inspect m} "
                    subscribe_to_list = Enum.shuffle(1..no_of_clients) |> List.delete(m) |> Enum.slice(1..subscribe_to_count)
                    Enum.each(subscribe_to_list, 
                        fn(n) ->
                                Client.subscribe(process_name, "Client" <> to_string(n))
                        end
                    )
                end
            end
        )
    end
    def start(no_of_clients) do
        Tweeter.start_link("Tweeter")
        
        # register clients
        start_time = :os.system_time(:millisecond)
        register_clients(no_of_clients)
        end_time = :os.system_time(:millisecond)
        time_registration = end_time-start_time
        #Process.sleep(1000)
        #subscribe clients according to zipf distribution
        start_time = :os.system_time(:millisecond)        
        subscribe_clients(no_of_clients)
        end_time = :os.system_time(:millisecond)
        time_subscribing = end_time-start_time
        
        #Process.sleep(2500)
        #send tweets according to zipf distribution
        start_time = :os.system_time(:millisecond)        
        send_tweets(no_of_clients)
        end_time = :os.system_time(:millisecond)
        time_tweeting = end_time-start_time
        
        
        #Process.sleep(2500)
        #calculate no of tweets sent in 1000ms
        #start_time = :os.system_time(:millisecond)
        #end_time = start_time
        #IO.puts "Difference #{inspect end_time - start_time}"
        #count = get_tweet_count(no_of_clients, 0, start_time, end_time)
        #IO.puts "Number of tweets in 1 second #{inspect count}"
        #implement logic for retweet
        retweet_count = 10000
        start_time = :os.system_time(:millisecond)
        retweet_messages(round(0.25 * no_of_clients), retweet_count) 
        end_time = :os.system_time(:millisecond)
        time_retweet  = end_time-start_time
        #Process.sleep(2500)
        #disconnect 25% clients
        no_disconnect_clients = round(0.25 * no_of_clients)
        clients_disconnected_list =  Enum.shuffle(1..no_of_clients) |> Enum.slice(1..no_disconnect_clients)
        start_time = :os.system_time(:millisecond)
        disconnect_clients(clients_disconnected_list)
        end_time = :os.system_time(:millisecond)
        time_disconnect = end_time-start_time
        #Process.sleep(2500)
        
        
        #invoke send tweet on random clients
        total_tweets_to_send = 100
        start_time = :os.system_time(:millisecond)
        send_tweets_by_random_clients(no_of_clients,total_tweets_to_send)
        end_time = :os.system_time(:millisecond)
        time_second_tweet = end_time-start_time
        #Process.sleep(2500)
        #Restart the stopped clients
        start_time = :os.system_time(:millisecond)
        restart_disconnected_clients(clients_disconnected_list)
        end_time = :os.system_time(:millisecond)
        time_restart = end_time-start_time
        #Process.sleep(2500)
        #invoke send tweet on the restarted clients
        start_time = :os.system_time(:millisecond)       
        send_tweets_clientlist(no_of_clients, clients_disconnected_list)
        end_time = :os.system_time(:millisecond)
        time_restart = end_time-start_time
        IO.puts "Registration completion time: #{inspect time_registration}"
        IO.puts "Subscribing completion time: #{inspect time_subscribing}"
        IO.puts "Sending tweets completion time: #{inspect time_tweeting}"
        IO.puts "Retweeting completion time: #{inspect time_retweet}"
        IO.puts "Disconnection completion time: #{inspect time_disconnect}"
        IO.puts "Second phase sending tweets completion time: #{inspect time_second_tweet}"
        IO.puts "Restart disconnected users completion time: #{inspect time_restart}"
        IO.puts "Restarted users sending tweets completion time: #{inspect time_restart}"
        #Process.sleep(2500)
        Process.sleep(100000)
    end
end