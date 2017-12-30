defmodule GenerateTweet do
    
    defp randomizer(length, type \\ :all) do
        alphabets = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        numbers = "0123456789"
    
        lists =
          cond do
            type == :alpha -> alphabets <> String.downcase(alphabets)
            type == :numeric -> numbers
            type == :upcase -> alphabets
            type == :downcase -> String.downcase(alphabets)
            true -> alphabets <> String.downcase(alphabets) <> numbers
          end
          |> String.split("", trim: true)
    
        do_randomizer(length, lists)
      end
    
      @doc false
      defp get_range(length) when length > 1, do: (1..length)
      defp get_range(length), do: [1]
    
      @doc false
      defp do_randomizer(length, lists) do
        get_range(length)
        |> Enum.reduce([], fn(_, acc) -> [Enum.random(lists) | acc] end)
        |> Enum.join("")
      end
    
    defp make_list_of_words(list, n) when n <= 0 do
        list
    end
    
    defp make_list_of_words(list, n) when n > 0 do
        string = to_string(randomizer(5))
        list = list ++ [string]
        n = n - 1
        make_list_of_words(list, n) 
    end

    defp add_hashtags(list, n) when n <= 0 do
        list
    end


    defp add_hashtags(list, n) when n > 0 do
        list = list ++ ["#" <> to_string(randomizer(5))]
        n = n - 1
        add_hashtags(list, n)
    end
    
    
    def make_tweet(no_of_clients) do
        #generate random tweet of length n
        n = Enum.random(3..10)
        list = []
        list = make_list_of_words(list, n)
        client_no = :rand.uniform(no_of_clients)
        list = list ++ ["@Client" <> to_string(client_no)]
        list = add_hashtags(list, :rand.uniform(3)) 
        words = Enum.shuffle(list) |> Enum.join(" ")
    end

end

