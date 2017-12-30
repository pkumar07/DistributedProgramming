defmodule Tweeter do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    
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
    
    #store key: :count, value: tweet_count    
    tweet_count = :ets.new(:tweet_count, [:set, :named_table, :public, read_concurrency: true, 
    write_concurrency: false])
    
    #store key: process_name, value: socket    
    user_socks = :ets.new(:user_socks, [:set, :named_table, :public, read_concurrency: true, 
    write_concurrency: false])

    children = [
      # Start the endpoint when the application starts
      supervisor(Tweeter.Endpoint, []),
     # worker(Tweeter.SocketClient, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tweeter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Tweeter.Endpoint.config_change(changed, removed)
    :ok
  end
end