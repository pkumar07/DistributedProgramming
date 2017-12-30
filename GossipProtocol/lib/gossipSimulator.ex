defmodule GossipSimulator do
    
    def start(num_of_nodes, topology, algorithm) do
        # Retrieve the fully qualified server node ip
        {ok, [{ip_comma, gateway,subnet}, {_,_,_}]} = :inet.getif 
        ip = :inet.ntoa(ip_comma)       
        qip = "project" <> "@" <> to_string(ip)
        #qip = "project" <> "@" <> "192.168.56.1"
        
        # Start the gossipSimulator node 
        unless Node.alive?() do
            Node.start(String.to_atom(qip))
        end
        
        ref =  construct_topology(topology, num_of_nodes, qip, 0, 0, 0, [], num_of_nodes, :ref)
    
        # Record the start time and globally register it
        start_time = :os.system_time(:millisecond)
        
        # Spawn master process       
        mpid = Node.spawn_link(String.to_atom(qip), GossipSimulator, :master, [qip, start_time, num_of_nodes, topology, 0, algorithm])
        :global.register_name(:master, mpid)
        #IO.puts "master is #{inspect mpid}"
        #IO.inspect mpid
        # Send message to master process
        send mpid, {:start, topology}
        
        # Trap exit errors from gossipSimulator linked processes  
        Process.flag(:trap_exit, true)
        
        receive do
            {:EXIT, pid, :normal} ->
                IO.inspect "Normal exit in gossipSimulator start from #{inspect pid}"
            {:EXIT, pid, msg} ->
                IO.inspect "Exit in gossipSimulator start from #{inspect pid}"
                IO.inspect msg
            {:DOWN, ref, :process, npid, :normal} ->
                IO.puts "Normal exit in Agent from #{inspect npid}"                
            {:DOWN, ref, :process, npid, msg} ->
                IO.puts "Received :DOWN in master from #{inspect npid}"
                IO.inspect msg
        end
    end
    
    def master(qip, start_time, num_of_nodes, topology, num_of_nodes_terminated, algorithm) do
        receive do
            {:start, topology} ->
                cond do
                    topology == "line" or topology == "full"  ->
                        neighbors_list = Agent.get(:global.whereis_name(:agent), fn(state) -> state end)
                        rand_index = :rand.uniform(num_of_nodes)-1
                        random_neighbor = Enum.at(neighbors_list, rand_index)   
                    topology == "2D" or topology == "imp2D" ->
                        neighbors_list_2D = Agent.get(:global.whereis_name(:agent), fn(state) -> state end)
                        sqr_root = round(:math.sqrt(num_of_nodes))
                        random_i = :rand.uniform(sqr_root)-1
                        random_j = :rand.uniform(sqr_root)-1
                        random_neighbor = neighbors_list_2D[random_i][random_j]
                end
                
                if algorithm == "gossip" do
                    #IO.puts "send_rumor to random neighbor #{inspect random_neighbor}"
                    send random_neighbor, {:send_rumor, self}
                else
                    #IO.puts "send_push_sum to random neighbyor #{inspect random_neighbor}" 
                    #IO.puts "random_neighbor is #{inspect random_neighbor}"
                    send random_neighbor, {:send_push_sum, 0, 0, self}
                end   
            
            {:terminate, npid, timer} ->
                num_of_nodes_terminated = num_of_nodes_terminated + 1
                #IO.puts "num_oooooooooooooooooooooooooooooooooooooooooooooooooooof_nodes_terminated are #{inspect num_of_nodes_terminated}"
                if algorithm != "gossip" do
                    num_of_nodes = round(0.65*num_of_nodes)
                end
                if num_of_nodes_terminated == num_of_nodes do
                    end_time = :os.system_time(:millisecond)
                    IO.puts("The amount of time taken to achieve convergence of the "<> topology <> " algorithm is " <> Integer.to_string(end_time - start_time) )
                    System.halt(0)
                end
            
            {:DOWN, ref, :process, npid, :normal} ->
                IO.puts "Normal exit in master from #{inspect npid}"
            
            {:DOWN, ref, :process, npid, msg} ->
                IO.puts "Received :DOWN in master from #{inspect npid}"
                IO.inspect msg
        end
        master(qip, start_time, num_of_nodes,topology, num_of_nodes_terminated, algorithm)
    end
                    
    def neighbor(rumor_count, s, w, i, j, timer1, timer2, count, num_of_nodes, topology, terminated, timer_on) do
        receive do
            {:send_rumor, mpid} ->
                if timer_on == 0 do 
                    #IO.puts "send_rumor received for #{inspect self}"
                    {_, timer1} = :timer.send_interval(5, self, {:propogate_rumor, mpid})            
                    timer_on = 1
                else
                    send self, {:propogate_rumor, mpid}
                end

            {:propogate_rumor, mpid} ->
                #IO.puts "propogate_rumor received for #{inspect self} with rumor_count #{inspect rumor_count} and terminated #{inspect terminated}"
                if rumor_count < 10 do
                    rumor_count = rumor_count + 1
                    random_neighbor = get_neighbor(self, topology, num_of_nodes,  i, j)
                    #IO.puts "random_neighbor #{inspect random_neighbor} picked for #{inspect self} with rumour_count #{inspect rumor_count}"
                    send random_neighbor,{:send_rumor, self}  
                else
                    :timer.cancel(timer1)
                    if terminated == 0 do
                        #IO.puts "gossip limit reached! send terminate to neighbor #{inspect self} with count #{inspect count} and timer #{inspect timer1}"
                        send :global.whereis_name(:master), {:terminate, self, timer1}
                        terminated = 1
                    end
                end
            
            {:send_push_sum, new_s, new_w, mpid} ->
                #IO.puts "send_push_sum received for #{inspect self} with s #{inspect s} and w #{inspect w} , with new_s #{inspect new_s} and new_w #{inspect new_w}"
                prev_ratio = s/w
                s = s + new_s
                w = w + new_w
                new_ratio = s/w
                rumor_count = rumor_count + 1
                if timer_on == 0 do
                    {_, timer2} = :timer.send_interval(5, self, {:propogate_push_sum, prev_ratio, new_ratio, mpid})
                    timer_on = 1
                else
                    send self, {:propogate_push_sum, prev_ratio, new_ratio, mpid}
                end

            {:propogate_push_sum, prev_ratio, new_ratio, mpid} ->
                #IO.puts "propogate_push_sum received for #{inspect self} with diff #{inspect abs(new_ratio - prev_ratio) < :math.pow(10,-10)}, s #{inspect s}, w #{inspect w} count #{inspect count}, rumor_count #{inspect rumor_count}"    
                #IO.puts "prev_ratio: #{inspect prev_ratio} and new_ratio: #{inspect new_ratio} for neighbor #{inspect self}"
                
                if ( abs(new_ratio - prev_ratio) < :math.pow(10,-10) and rumor_count > 1) do
                    count = count + 1
                    if (count == 3) do
                        if terminated == 0 do
                            :timer.cancel(timer2)
                            #IO.puts "push_sum limit reached! send terminate to neighbor #{inspect self}"
                            send :global.whereis_name(:master), {:terminate,self, timer2}
                            terminated = 1
                        end
                    end
                else
                    if terminated != 1 do
                        s = s/2
                        w = w/2
                        count = 0
                        random_neighbor = get_neighbor(self, topology, num_of_nodes,  i, j)
                        #IO.puts "random_neighbor #{inspect random_neighbor} picked for #{inspect self}, sending push_sum with s #{inspect s} and w #{inspect w}"
                        send random_neighbor,{:send_push_sum, s, w, self}
                    end
                end
                neighbor(rumor_count, s, w, i, j, timer1, timer2, count, num_of_nodes, topology, terminated, timer_on)
        end 
        neighbor(rumor_count, s, w, i, j, timer1, timer2, count, num_of_nodes, topology, terminated, timer_on)       
    end
      
    def from_list(list) when is_list(list) do
        do_from_list(list)
    end
    
    defp do_from_list(list, map \\ %{}, index \\ 0)
    defp do_from_list([], map, _index), do: map
    defp do_from_list([h|t], map, index) do
        map = Map.put(map, index, do_from_list(h))
        do_from_list(t, map, index + 1)
    end
    defp do_from_list(other, _, _), do: other
    
    def update_matrix(neighbors_list_2D, qip, count, r, c, sqr_root, num_of_nodes, topology, ref) do
        if r < sqr_root do
            if c < sqr_root do
                count = count + 1
                npid = Node.spawn(String.to_atom(qip), GossipSimulator, :neighbor, [0, count, 1.0, r, c, :timer1, :timer2, 0, num_of_nodes, topology, 0, 0])
                ref = Process.monitor(npid)
                neighbors_list_2D = Matrix.set(neighbors_list_2D, r, c, npid)
                c = c + 1
                update_matrix(neighbors_list_2D, qip, count, r, c, sqr_root, num_of_nodes, topology, ref)
            
            else
                r = r + 1
                c = 0
                update_matrix(neighbors_list_2D, qip, count, r, c, sqr_root, num_of_nodes, topology, ref)
            end
        else
            {neighbors_list_2D, ref}
        end
    end
                        
    def construct_topology(topology, num_of_nodes, qip, count, r, c, neighbors_list, num_of_nodes2, ref) do    
        cond do 
            topology == "line" or topology == "full"  ->
                if num_of_nodes2 > 0 do
                    count = count + 1
                    npid = Node.spawn(String.to_atom(qip), GossipSimulator, :neighbor, [0, count+1, 1.0, (num_of_nodes - count) , 0, :timer1 ,:timer2, 0, num_of_nodes, topology, 0, 0])
                    ref = Process.monitor(npid)
                    neighbors_list = [npid | neighbors_list]
                    num_of_nodes2 = num_of_nodes2 - 1 
                    construct_topology(topology, num_of_nodes, qip, count, r, c, neighbors_list, num_of_nodes2, ref)             
                else
                    neighbors_list
                    {:ok, agent} = Agent.start_link(fn -> neighbors_list end)
                    :global.register_name(:agent,agent)
                end
                            
            topology == "2D" or topology == "imp2D" ->
                sqr_root = round(:math.sqrt(num_of_nodes))  
                neighbors_list_2D = Matrix.new(sqr_root,sqr_root, :pid)
                {neighbors_list_2D, ref} = update_matrix(neighbors_list_2D, qip, count, r, c, sqr_root, num_of_nodes, topology, ref)
                neighbors_list_2D = from_list(neighbors_list_2D)
                # start agent and globally register agent process id
                {:ok, agent} = Agent.start_link(fn -> neighbors_list_2D end)
                :global.register_name(:agent,agent)
        end  
    end
    
    def to_list(matrix) when is_map(matrix) do
        do_to_list(matrix)
    end
    
    defp do_to_list(matrix) when is_map(matrix) do
        for {_index, value} <- matrix,
            into: [],
            do: do_to_list(value)
        end
    defp do_to_list(other), do: other
    
    def get_neighbor(neighbor, topology, num_of_nodes, i, j) do
        neighbors_list = Agent.get(:global.whereis_name(:agent), fn(state) -> state end) 
        cond do 
            topology == "line" ->        
                cond do
                    i == 0 ->
                        random_neighbor = Enum.at(neighbors_list, i + 1)
                    i == num_of_nodes - 1  ->
                        random_neighbor = Enum.at(neighbors_list, i - 1)
                    true ->
                        list = [i-1, i+1]
                        index = list |> Enum.shuffle |> hd 
                        random_neighbor = Enum.at(neighbors_list, index)
                end  
                random_neighbor
            
            topology == "full" ->
                rand_index = :rand.uniform(num_of_nodes)-1 
                if rand_index == i do
                    if i == num_of_nodes-1 do
                        random_neighbor = Enum.at(neighbors_list, i - 1)
                    else
                        if i == 0 do
                            random_neighbor = Enum.at(neighbors_list, i + 1)
                        else
                            random_neighbor = Enum.at(neighbors_list, rand_index + 1)     
                        end   
                    end
                    
                else
                    random_neighbor = Enum.at(neighbors_list, rand_index)
                end
                random_neighbor
                
            topology == "2D" or topology == "imp2D" ->
                list = []
                index_list= []
                sqr_root = round(:math.sqrt(num_of_nodes)) 
                if i-1 >= 0 do 
                     index_list = [[i-1,j] | index_list]
                end
                if i+1 < sqr_root do 
                    index_list = [[i+1,j] | index_list]
                end
                if j-1 >= 0 do 
                    index_list = [[i,j-1] | index_list]
                end
                if j+1 < sqr_root do 
                    index_list = [[i,j+1] | index_list]
                end     
              
                [random_i, random_j] = index_list |> Enum.shuffle |> hd 
                random_neighbor = neighbors_list[random_i][random_j]
                #IO.puts "Random neighbor is #{inspect random_neighbor}"
                random_neighbor
                if topology == "imp2D" do
                    sqr_root = round(:math.sqrt(num_of_nodes))
                    random_i = :rand.uniform(sqr_root) - 1
                    random_j = :rand.uniform(sqr_root) - 1
                    [random_i, random_j] = find_random(index_list, random_i, random_j, num_of_nodes)
                    random_neighbor = neighbors_list[random_i][random_j]
                end
                random_neighbor
        end
    end
    
    def find_random(index_list, random_i, random_j, num_of_nodes) do
        if random_i == Enum.at(index_list, 0) do
            random_i = random_i + 1
            find_random(index_list, random_i, random_j, num_of_nodes)
        end
        if random_j == Enum.at(index_list, 1) do 
            random_j = random_j + 1
            find_random(index_list, random_i, random_j, num_of_nodes)
        end
        [random_i, random_j]
    end
end