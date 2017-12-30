defmodule Project4part1final do

  def main(args) do
    args |> parse_args |> delegate
  end
  defp parse_args(args) do
    {_,arg,_} = OptionParser.parse(args)
     arg
  end

  def delegate([]) do
      IO.puts "Null argument received,"
  end

  def delegate(arg) do
       # IO.inspect arg
        num_of_clients = String.to_integer(Enum.at(arg,0))
       # total_subscribers = String.to_integer(Enum.at(arg,1))
        #Project4Part1Simulator.start(num_of_clients, total_subscribers)
       Project4Part1Simulator.start(num_of_clients)
        #SimulationTest.start(num_of_clients)
  
     
  end
end
