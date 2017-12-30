defmodule Project3bonus do
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
        numFail = String.to_integer(Enum.at(arg,2))
        FailureModel.start(numNodes,numRequests,numFail)    
     end
  end