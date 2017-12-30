defmodule Project2 do
  @moduledoc """
  Documentation for Project2.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Project2.hello
      :world

  """
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
        numNodes = String.to_integer(Enum.at(arg,0))
        topology = Enum.at(arg,1)
        algorithm = Enum.at(arg,2)
        #failure = String.to_integer(Enum.at(arg,3))
      #  IO.puts "numNodes #{inspect numNodes}, topology #{inspect topology}, algo #{inspect algorithm}"
        #MODA.main(numNodes,topology,algorithm)
        GossipSimulator.start(numNodes,topology,algorithm)
        #GossipSimulator2.start(numNodes,topology,algorithm, failure)
        #MyModule.start(numNodes,topology,algorithm)
     
  end
end