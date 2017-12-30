defmodule Project3 do
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
      numNodes = String.to_integer(Enum.at(arg,0))
      numRequests = String.to_integer(Enum.at(arg,1))
      PastryProtocol.start(numNodes,numRequests)
   end
end