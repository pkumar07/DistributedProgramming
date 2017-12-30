defmodule Project1 do
    def main(args) do
        args |> parse_args |> delegate
    end

    defp parse_args(args) do
        {_,arg,_} = OptionParser.parse(args)
        hd(arg)
    end

    def delegate([]) do
        IO.puts "Null argument received,"
    end

    def delegate(arg) do
        if not String.contains?(arg, ".") do
            Server.start(String.to_integer(arg))
        else 
            Client.connect(arg)
        end
    end
end
