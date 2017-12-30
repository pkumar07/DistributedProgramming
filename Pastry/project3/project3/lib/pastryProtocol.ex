defmodule PastryProtocol do
    
    def start(num_of_nodes, num_of_requests) do
        # Spawn master process       
        mpid = spawn_link(PastryProtocol, :master, [num_of_nodes, num_of_requests, 0, 0])
        :global.register_name(:master, mpid)
        #IO.inspect "master: #{inspect mpid}"    

        # Send message to master process
        send mpid, {:construct_topology}

        # Trap exit errors from gossipSimulator linked processes  
        Process.flag(:trap_exit, true)
        
        receive do
            {:EXIT, pid, :normal} ->
                IO.inspect "Normal exit from master"
            {:EXIT, pid, msg} ->
                IO.inspect "Exit in PastryProtocol start from #{inspect pid}"
                IO.inspect msg             
        end
    end
    
    def master(num_of_nodes, num_of_requests, total_hopcount, num_routed) do
        receive do
            {:construct_topology} ->
                node_digits = 8 
                node_index = 8
                b = 2
                {node_list, node_map, sorted_node_list, node_digits, node_index, b} = construct_topology(num_of_nodes, num_of_requests, 0, %{} , [], node_digits, node_index, b)
                #IO.puts "In construct_topology"
                #IO.puts "Node_List #{inspect node_list}"
                #IO.puts "Sorted_Node_List #{inspect sorted_node_list}"
                #IO.puts "Node_map #{inspect node_map}"
                {node_map, node_list} = build_maps(num_of_nodes, num_of_requests, node_list, node_map, sorted_node_list, node_digits, node_index, b)
                send self, {:initiate_routing, node_map, node_list, 0}
            
            {:initiate_routing, node_map, node_list, count} ->
                if count < num_of_nodes do 
                    node_id = Map.get(node_list, count)
                    #IO.puts "Send start_routing to #{inspect Map.get(node_map, node_id)} with node_id #{inspect node_id}" 
                    send Map.get(node_map, node_id), {:start_routing}
                    count = count + 1
                    #IO.puts "Send initiate_routing to itself with pid #{inspect self} with count #{inspect count}"
                    send self, {:initiate_routing, node_map, node_list, count}
                end 
            
            {:terminate, hop_count} ->
                total_hopcount = total_hopcount + hop_count
                num_routed =  num_routed + 1
                #IO.puts "terminate!!!!!!!!!!!!!!!!!!!!!!with num_routed #{inspect num_routed} and product #{inspect num_of_nodes * num_of_requests} with total_hopcount #{inspect total_hopcount}"
                if(num_routed == num_of_nodes * num_of_requests) do
                    average = total_hopcount/num_routed
                    IO.puts "Average hops per route is #{inspect average}"
                    System.halt(0)
                end
            
            {:DOWN, ref, :process, npid, :normal} ->
                IO.puts "Normal exit in master from #{inspect npid}"
            
            {:DOWN, ref, :process, npid, msg} ->
                IO.puts "Received :DOWN in master from #{inspect npid}"
                IO.inspect msg
        end
        master(num_of_nodes, num_of_requests, total_hopcount, num_routed)
    end
                    
    def node(node_id, num_of_nodes, num_of_requests, node_digits, node_index, b, node_map, node_list, left_leaf_set, right_leaf_set, routing_table, neighbor_set, count, timer, hop_count) do
        receive do
            {:initialize, node_id, num_of_nodes, num_of_requests, node_digits, node_index, b, node_map, node_list, left_leaf_set, right_leaf_set, routing_table, neighbor_set, count, timer, hop_count} ->
                node(node_id, num_of_nodes, num_of_requests, node_digits, node_index, b, node_map, node_list, left_leaf_set, right_leaf_set, routing_table, neighbor_set, count, timer, hop_count)                     
            
            {:start_routing} ->
                #IO.puts "start timer for pid #{inspect self}"
                {_, timer} = :timer.send_interval(1000, self, {:route_requests})
                node(node_id, num_of_nodes, num_of_requests, node_digits, node_index, b, node_map, node_list, left_leaf_set, right_leaf_set, routing_table, neighbor_set, count, timer, hop_count)
            
            {:route_requests} ->
                node_requests(self, num_of_requests, num_of_nodes, node_id, node_digits, node_index, b, count, timer)
                                
            {:route, key, msg, hop_received} ->
                key_int = List.to_integer(key)
                #IO.puts "In route for node_id #{inspect node_id} with pid #{inspect self} with key #{inspect key}, with hop_received #{inspect hop_received}"
                #hop_count = hop_received
                if node_id == key do
                    send :global.whereis_name(:master), {:terminate, hop_received + 1}
                else
                    send self, {:send_route_node, key, msg, hop_received, key_int} 
                end
                #node(node_id, num_of_nodes, num_of_requests, node_digits, node_index, b, node_map, node_list, left_leaf_set, right_leaf_set, routing_table, neighbor_set, count, timer, hop_count)
            
            {:send_route_node, key, msg, hop_received, key_int} ->    
                
                #route_node = node_id
                #IO.puts "leaf_set is #{inspect leaf_set}"
                #IO.puts "neighbor_set is #{inspect neighbor_set}"
                #IO.puts "routing_table is #{inspect routing_table} for node_id #{inspect node_id} with size #{inspect Matrix.size(routing_table)} with pid #{inspect self}"
                #IO.puts "In send_route_node for pid #{inspect self} with node_id #{inspect node_id} with leaf_set extremes #{inspect List.to_integer(Map.get(leaf_set, node_digits-1))} and #{inspect List.to_integer(Map.get(leaf_set, 0))}"
                right_max = Map.get(right_leaf_set, Map.size(right_leaf_set)-1)
                left_min = Map.get(left_leaf_set, 0)
                if right_max != :nil do
                    right_max = List.to_integer(right_max)
                    #IO.puts "right_max #{inspect right_max} and left_min #{inspect left_min} and #{inspect Map.size(left_leaf_set)} and #{inspect Map.size(right_leaf_set)}"
                end
                if left_min != :nil do
                    left_min = List.to_integer(left_min)
                    #IO.puts "right_max #{inspect right_max} and left_min #{inspect left_min} and #{inspect Map.size(left_leaf_set)} and #{inspect Map.size(right_leaf_set)}"
                end
            
            if ( Map.size(right_leaf_set) > 0 and key_int <= right_max and key_int > List.to_integer(node_id)) or
               ( Map.size(left_leaf_set) > 0 and key_int >= left_min and key_int < List.to_integer(node_id)) do        
                # from left_leaf_set
                left_min = Map.get(left_leaf_set, 0)
                if left_min != :nil do
                    left_min = List.to_integer(left_min)
                    #IO.puts "right_max #{inspect right_max} and left_min #{inspect left_min} and #{inspect Map.size(left_leaf_set)} and #{inspect Map.size(right_leaf_set)}"
                end
                if Map.size(left_leaf_set) > 0 and key_int >= left_min and key_int < List.to_integer(node_id) do
                    route_node = Map.get(left_leaf_set, 0)
                    distance = abs(key_int - List.to_integer(route_node))
                    size = Map.size(left_leaf_set)
                    {route_node, distance} = nearest_leaf(key_int, left_leaf_set, 1, node_digits, route_node, distance, size)           
                    #IO.puts "From left_leaf_set for node_id #{inspect node_id} and key #{inspect key} to route_node #{inspect route_node} with left_leaf_set #{inspect left_leaf_set}"
                else 
                    # from right_leaf_set
                    right_max = Map.get(right_leaf_set, Map.size(right_leaf_set)-1)
                    if right_max != :nil do
                        right_max = List.to_integer(right_max)
                        #IO.puts "right_max #{inspect right_max} and left_min #{inspect left_min} and #{inspect Map.size(left_leaf_set)} and #{inspect Map.size(right_leaf_set)}"
                    end
                    if Map.size(right_leaf_set) > 0 and key_int <= right_max and key_int > List.to_integer(node_id) do
                        route_node = Map.get(right_leaf_set, Map.size(right_leaf_set)-1)
                        #IO.puts "hereeee with node_id #{inspect node_id} size #{inspect Map.size(right_leaf_set)-1} with right_leaf_set #{inspect right_leaf_set}"
                        distance = abs(key_int - List.to_integer(route_node))
                        size = Map.size(right_leaf_set)
                        {route_node, distance} = nearest_leaf(key_int, right_leaf_set, 1, node_digits, route_node, distance, size)           
                        #IO.puts "From right_leaf_set for node_id #{inspect node_id} and key #{inspect key} to route_node #{inspect route_node} with right_leaf_set #{inspect right_leaf_set}"
                    end
                end
                if distance != :nil do
                    if abs(key_int - List.to_integer(node_id)) < distance do
                        route_node = node_id
                    end
                end
            else
                if Map.size(left_leaf_set) > 0 and key_int < List.to_integer(Map.get(left_leaf_set, 0)) do
                    route_node = Map.get(left_leaf_set, 0)
                    
                    # check routing_table entries too
                    matched_index = -1
                    returned_index = findPrefix(key, node_id, 0)
                    if returned_index > 0 do
                        matched_index = returned_index + 1
                    else
                        matched_index = 0
                    end
                    col = String.to_integer(List.to_string([Enum.at(key, matched_index)]))
                    if Matrix.elem(routing_table, matched_index, col) != '' and matched_index >= 0 do   
                        route_node2 = Matrix.elem(routing_table, matched_index, col) 
                        if abs(List.to_integer(route_node2) - key_int) < abs(List.to_integer(route_node) - key_int) do
                            route_node = route_node2
                            #IO.puts "From outttt of left_leaf_set routing_table for node_id #{inspect node_id} and key #{inspect key} to route_node #{inspect route_node} with #{inspect abs(List.to_integer(route_node2) - key_int)} and #{inspect abs(List.to_integer(route_node) - key_int)}"
                        end    
                    end

                    #IO.puts "From out of left_leaf_set for node_id #{inspect node_id} and key #{inspect key} to route_node #{inspect route_node} with left_leaf_set #{inspect left_leaf_set}"
                else
                    if Map.size(right_leaf_set) > 0 and key_int > List.to_integer(Map.get(right_leaf_set, Map.size(right_leaf_set)-1)) do
                        route_node = Map.get(right_leaf_set, Map.size(right_leaf_set)-1)
                        
                        # check routing_table entries too
                        matched_index = -1
                        returned_index = findPrefix(key, node_id, 0)
                        if returned_index > 0 do
                            matched_index = returned_index + 1
                        else
                            matched_index = 0
                        end
                        col = String.to_integer(List.to_string([Enum.at(key, matched_index)]))
                        if Matrix.elem(routing_table, matched_index, col) != '' and matched_index >= 0 do   
                            route_node2 = Matrix.elem(routing_table, matched_index, col) 
                            if abs(List.to_integer(route_node2) - key_int) < abs(List.to_integer(route_node) - key_int) do
                                route_node = route_node2
                                #IO.puts "From outttt of right_leaf_set routing_table for node_id #{inspect node_id} and key #{inspect key} to route_node #{inspect route_node} with #{inspect abs(List.to_integer(route_node2) - key_int)} and #{inspect abs(List.to_integer(route_node) - key_int)}"
                            end    
                        end

                        #IO.puts "From out of right_leaf_set for node_id #{inspect node_id} and key #{inspect key} to route_node #{inspect route_node} with right_leaf_set #{inspect right_leaf_set}"
                    else
                        if (Map.size(left_leaf_set) == 0 and key_int < List.to_integer(node_id)) or
                            (Map.size(right_leaf_set) == 0 and key_int > List.to_integer(node_id)) do
                            route_node = node_id
                            #IO.puts "From empty left/right leaf_sets for node_id #{inspect node_id} and key #{inspect key} to route_node #{inspect route_node}"
                        # from routing_table
                        else 
                            matched_index = -1
                            returned_index = findPrefix(key, node_id, 0)
                            if returned_index > 0 do
                                matched_index = returned_index + 1
                            else
                                matched_index = 0
                            end
                            col = String.to_integer(List.to_string([Enum.at(key, matched_index)]))
                            if Matrix.elem(routing_table, matched_index, col) != '' and matched_index >= 0 do   
                                route_node = Matrix.elem(routing_table, matched_index, col) 
                                #IO.puts "From routing_table for node_id #{inspect node_id} and key #{inspect key} to route_node #{inspect route_node}"
                            # rare case
                            else
                                left_leaf_list = Enum.map(left_leaf_set, fn({key, value}) -> value end)
                                right_leaf_list = Enum.map(right_leaf_set, fn({key, value}) -> value end)
                                neighbors_list = Enum.map(neighbor_set, fn({key, value}) -> value end)
                                merged_list = left_leaf_list ++ right_leaf_list ++ neighbors_list
                                {rows, cols} = Matrix.size(routing_table)
                                merged_list = merge_routing_entries(merged_list, routing_table, rows, 0)
                                #IO.puts "merged_list is #{inspect merged_list}"
                                route_node = find_route_node(merged_list, key, key_int, 0, -1, '', node_id)
                                #IO.puts "From rare case for node_id #{inspect node_id} and key #{inspect key} to route_node #{inspect route_node}"
                            end
                        end
                    end
                end
            end        
            #IO.puts "Propogating send_route_node for node_id #{inspect node_id} to route_node #{inspect route_node} with key #{inspect key} with pid #{inspect self} with hop_received #{inspect (hop_received + 1)}"
    
            if route_node != node_id do
                send Map.get(node_map, route_node), {:route, key, msg, hop_received + 1}
            else
                send :global.whereis_name(:master), {:terminate, hop_received + 1}
            end
        end 
        node(node_id, num_of_nodes, num_of_requests, node_digits, node_index, b, node_map, node_list, left_leaf_set, right_leaf_set, routing_table, neighbor_set, count, timer, hop_count)
    end
 
    def node_requests(pid, num_of_requests, num_of_nodes, node_id, node_digits, node_index, b, count, timer) when count >= num_of_requests do
         :timer.cancel(timer)
    end
    def node_requests(pid, num_of_requests, num_of_nodes, node_id, node_digits, node_index, b, count, timer) when count < num_of_requests do
        #count = rem(count, num_of_nodes)
        key = build_nodeid("", node_index, node_digits, b)
        send pid, {:route, key, "pastry message", 0} 
        count = count + 1       
        node_requests(pid, num_of_requests, num_of_nodes, node_id, node_digits, node_index, b, count, timer)
    end
    
    defp find_route_node(merged_list, key, key_int, index, cur_matched_index, route_node, node_id) when index >= length(merged_list)do
        route_node
    end
    defp find_route_node(merged_list, key, key_int, index, cur_matched_index, route_node, node_id) when index < length(merged_list) do
        x = Enum.at(merged_list, index) 
        matched_index = findPrefix(x, key, 0)
        if matched_index > cur_matched_index do
                cur_matched_index = matched_index
                route_node = x
        else
            if matched_index == cur_matched_index do
                if abs(List.to_integer(x) - key_int) < abs(List.to_integer(node_id) - key_int) do
                    cur_matched_index = matched_index
                    route_node = x     
                end
            end
        end
        index = index + 1
        find_route_node(merged_list, key, key_int, index, cur_matched_index, route_node, node_id)
    end
    
    defp merge_routing_entries(merged_list, routing_table, rows, index) when index >= rows do
        merged_list
    end
    defp merge_routing_entries(merged_list, routing_table, rows, index) when index < rows do
        list_node = Enum.at(routing_table, index)
        #IO.puts "list_node is #{inspect list_node}"
        merged_list = merged_list ++ Enum.reject(list_node, fn(x) -> x == '' end)
        index = index +  1
        merge_routing_entries(merged_list, routing_table, rows, index)
    end
    
    defp nearest_leaf(key_int, leaf_set, count, node_digits, route_node, distance, size) when count >= size do
        {route_node, distance}
    end
    defp nearest_leaf(key_int, leaf_set, count, node_digits, route_node, distance, size) when count < size do
        if abs(key_int - List.to_integer(Map.get(leaf_set, count))) < distance do
            distance = abs(key_int - List.to_integer(Map.get(leaf_set, count)))
            route_node = Map.get(leaf_set, count)
        end    
        count = count + 1
        nearest_leaf(key_int, leaf_set, count, node_digits, route_node, distance, size)
    end
    
    defp construct_topology(num_of_nodes, num_of_requests, c, node_map, node_list1, node_digits, node_index, b) when c >= num_of_nodes do
        node_list = node_list1 |> Enum.with_index(0) |> Enum.map(fn {k,v} -> {v,k} end) |> Map.new
        sorted_node_list = Enum.sort(node_list1) |> Enum.with_index(0) |> Enum.map(fn {k,v}->{v,k} end) |> Map.new
        {node_list, node_map, sorted_node_list, node_digits, node_index, b}
    end
    defp construct_topology(num_of_nodes, num_of_requests, c, node_map, node_list1, node_digits, node_index, b) when c < num_of_nodes do
        nid = spawn(PastryProtocol, :node, [0, num_of_nodes, num_of_requests, node_digits, node_index, b, %{}, %{}, %{}, %{}, [[]], %{}, 0, :timer, 0])
        Process.monitor(nid)
        a = build_nodeid("",node_index, node_digits, b)
        node_list1 = [a] ++ node_list1
        node_map = Map.put(node_map, a, nid)
        construct_topology(num_of_nodes, num_of_requests, c+1, node_map, node_list1, node_digits, node_index, b)
    end
    
    def build_maps(num_of_nodes, num_of_requests, node_list, node_map, sorted_node_list, node_digits, node_index, b) do
        l = round(2 * :math.pow(2,b))
        half_l = round(l/2)
        #IO.puts "In build_maps with #{inspect l}"
        neighbor_set = Map.new()
        left_leaf_set = Map.new()
        right_leaf_set = Map.new()
        routing_table = Matrix.new(node_digits,b, '')   
        
        for count <- 0..num_of_nodes-1 do
            node_id = Map.get(node_list, count)
            
            # neighbor set
            neighbor_set = construct_neighbor_set(node_digits, %{}, node_list, 0, num_of_nodes)
        
            s = Map.size(sorted_node_list)
            # leaf set 
            if count - half_l < 0 do
                left_idx = 0
                left_count = rem(count, half_l) 
            else
                left_idx = count - half_l
                left_count = half_l
            end

            if count + half_l > s-1 do
                right_idx = count + 1
                right_count = s - count - 1     
            else
                right_idx = count + 1
                right_count = half_l
            end
        
            {left_leaf_set, right_leaf_set} = construct_leaf_set(sorted_node_list, left_idx, right_idx, left_count, right_count, count)

            # routing table
            {rows, cols} =  Matrix.size(routing_table) 
            routing_table = construct_routing_table(routing_table, node_id, node_list, 0, Map.size(node_list))

            # initialize each node
            send Map.get(node_map, node_id), {:initialize, node_id, num_of_nodes, num_of_requests, node_digits, node_index, b, node_map, node_list, left_leaf_set, right_leaf_set, routing_table, neighbor_set, 0, :timer, 0}
        end
        {node_map, node_list}
    end
    
    defp build_nodeid(node_id, node_index, node_digits, b) when node_index == 0 do
        to_charlist(node_id)
    end
    defp build_nodeid(node_id, node_index, node_digits, b) when node_index <= node_digits do 
        node_id = to_string(node_id) <> to_string(:rand.uniform(b) - 1)
        build_nodeid(node_id, node_index-1, node_digits, b)  
    end
    
    defp construct_routing_table(routing_table, node_id, node_list, index ,map_size) when index >= map_size do
        routing_table
    end
    defp construct_routing_table(routing_table, node_id, node_list, index, map_size) when index < map_size do
        node_ident = Map.get(node_list, index)
        if node_id != node_ident do 
            matched_index = -1
            returned_index = findPrefix(node_ident, node_id, 0)
            if returned_index > 0 do
                matched_index = returned_index + 1
            else
                matched_index = 0
            end
            col = String.to_integer(List.to_string([Enum.at(node_ident, matched_index)]))   
            if (Matrix.elem(routing_table, matched_index, col) == '' and matched_index >= 0) do
                routing_table = Matrix.set(routing_table, matched_index , col, node_ident)
            end
        end

        index = index + 1   
        construct_routing_table(routing_table, node_id, node_list, index, map_size)
    end

    defp construct_neighbor_set(node_digits, neighbor_set, node_list, neighbor_set_count, num_of_nodes) when neighbor_set_count == node_digits do
        neighbor_set
    end
    defp construct_neighbor_set(node_digits, neighbor_set, node_list, neighbor_set_count, num_of_nodes) when neighbor_set_count < node_digits do
        neighbor_set = Map.put(neighbor_set, neighbor_set_count, Map.get(node_list, rem(neighbor_set_count, num_of_nodes)))   
        neighbor_set_count = neighbor_set_count + 1
        construct_neighbor_set(node_digits, neighbor_set, node_list, neighbor_set_count, num_of_nodes)
    end
    
    defp construct_leaf_set(sorted_node_list, left_idx, right_idx, left_count, right_count, count) do
        left_leaf_set = construct_left_set(%{}, sorted_node_list, left_idx, right_idx, left_count, right_count, 0, count)
        right_leaf_set = construct_right_set(%{}, sorted_node_list, left_idx, right_idx, left_count, right_count, 0, count)
        {left_leaf_set, right_leaf_set}
    end
    defp construct_left_set(left_leaf_set, sorted_node_list, left_idx, right_idx, left_count, right_count, index, count) when left_count <= 0 do
        left_leaf_set
    end 
    defp construct_left_set(left_leaf_set, sorted_node_list, left_idx, right_idx, left_count, right_count, index, count) when left_count > 0 do
       #IO.puts "left_set values for count #{inspect count} left_idx #{inspect left_idx} left_count #{left_count}"
       if Map.get(sorted_node_list, left_idx) == :nil do
         IO.puts "nil in left_leaf for count #{inspect count} with left_count #{inspect left_count} with left_idx #{inspect left_idx}"
       end
       left_leaf_set = Map.put(left_leaf_set, index, Map.get(sorted_node_list, left_idx))
       index = index + 1
       left_count = left_count - 1
       left_idx = left_idx + 1
       construct_left_set(left_leaf_set, sorted_node_list, left_idx, right_idx, left_count, right_count, index, count)
    end

    defp construct_right_set(right_leaf_set, sorted_node_list, left_idx, right_idx, left_count, right_count, index, count) when right_count <=0 do
        right_leaf_set
    end 
    defp construct_right_set(right_leaf_set, sorted_node_list, left_idx, right_idx, left_count, right_count, index, count) when right_count > 0 do
      #IO.puts "right_set values for count #{inspect count} right_idx #{inspect right_idx} right_count #{right_count}" 
      if Map.get(sorted_node_list, right_idx) == :nil do
        IO.puts "nil in right_leaf for count #{inspect count} with right_count #{inspect right_count} with right_idx #{inspect right_idx}"    
       end
       right_leaf_set = Map.put(right_leaf_set, index, Map.get(sorted_node_list, right_idx))
       index = index + 1
       right_count = right_count - 1
       right_idx = right_idx + 1
       construct_right_set(right_leaf_set, sorted_node_list, left_idx, right_idx, left_count, right_count, index, count) 
    end

    def findPrefix(str1,str2,i) do
        if i < length(str1) && i < length(str2) do
            if Enum.at(str1,i) == Enum.at(str2,i) do
                findPrefix(str1,str2,i+1)
            else
                i - 1
            end
        else
            i - 1 
        end
    end
end