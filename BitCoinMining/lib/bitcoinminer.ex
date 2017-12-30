defmodule Bitcoinminer do
  
  def main(num_of_zeros, work_unit_size) do
    length = 9
    list = []
    alpha_num_str = :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
    list = mine_coins(alpha_num_str, num_of_zeros, 0, list, work_unit_size)
    list
  end
    
  def mine_coins(alpha_num_str, num_of_zeros, nonce, list, work_unit_size) when work_unit_size <= 0 do  
    list
  end
    
  def mine_coins(alpha_num_str, num_of_zeros, nonce, list, work_unit_size) when work_unit_size > 0 do
    input = "pkumar07"<> alpha_num_str <> Integer.to_string(nonce)
    hash = hasher(input)
    valid_bitcoin = check_for_zeros(hash, num_of_zeros)
    if (valid_bitcoin) do 
      list = [input <> "\t"<> hash | list]
      work_unit_size = work_unit_size - 1
    end  
    mine_coins(alpha_num_str, num_of_zeros, nonce + 1, list, work_unit_size)
  end
  
  def check_for_zeros(input_string, num_of_zeros) do
    zeros_string = "0000000000000000000000000000000000000000000000000"
    if( String.slice(input_string, 0..(num_of_zeros-1)) == String.slice(zeros_string, 0..(num_of_zeros-1)) ) do
      true
    else
      false 
    end
  end
    
  def hasher(input_string) do
    Base.encode16(:crypto.hash(:sha256, input_string))
  end   
 
end 