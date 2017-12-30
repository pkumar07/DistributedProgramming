defmodule Server do
    def start(k) do
        # Set the workers_count and work_ildunit_size
        workers_count = System.schedulers_online
        work_unit_size = 10

        # Retrieve the fully qualified server node ip
        {ok, [{ip_comma, gateway,subnet}, {_,_,_}]} = :inet.getif 
        ip = :inet.ntoa(ip_comma)       
        qip = "project" <> "@" <> to_string(ip)

        # Start the server node and set cookie
        unless Node.alive?() do
            Node.start(String.to_atom(qip))
        end
        Node.set_cookie(Node.self, :"chocolate-chip")

        # Spawn master, printer and client_work_assigner processes on server node
        ppid = Node.spawn_link(String.to_atom(qip), Server, :printer, [])        
        mpid = Node.spawn_link(String.to_atom(qip), Server, :master, [workers_count, k, ppid, qip, work_unit_size])
        apid = Node.spawn_link(String.to_atom(qip), Server, :client_work_assigner, [k, work_unit_size])

        # Globally register server client_work_assigner's pid
        :global.register_name(:client_work_assignerid, apid)

        # Send start_mining message to server master process
        send mpid, {:start_mining, k, work_unit_size, workers_count}

        # Trap exit errors from server spawned processes  
        Process.flag(:trap_exit, true)

        receive do
            {:EXIT, pid, :normal} ->
                IO.inspect "Normal exit in server start from #{inspect pid}"
            {:EXIT, pid, msg} ->
                IO.inspect ":EXIT received in server start from #{inspect pid}"
                IO.inspect msg
        end
    end

    def master(workers_count,k, ppid, qip, work_unit_size) do
        receive do
            {:start_mining, k, work_unit_size, workers_count} ->
                if workers_count>0 do
                    wpid = Node.spawn(String.to_atom(qip), Server, :worker, [])
                    ref = Process.monitor(wpid)
                    #IO.puts "send mine_coins server to worker process #{inspect wpid}"
                    send wpid, {:mine_coins, k, work_unit_size, self()}
                    workers_count = workers_count - 1
                    send self, {:start_mining, k, work_unit_size, workers_count}
                end
                master(workers_count, k, ppid, qip, work_unit_size)
            {:collect_mined_coins, mined_coins_list} ->
                #IO.puts "received collect_mined_coins message in server master"
                send ppid, {:print_mined_coins, mined_coins_list}
                master(workers_count, k, ppid, qip, work_unit_size)
            {:DOWN, ref, :process, wpid, :normal} ->
                IO.puts "Normal exit in server master from #{inspect wpid}"
                master(workers_count-1, k, ppid, qip, work_unit_size)
            {:DOWN, ref, :process, wpid, msg} ->
                IO.puts "Received :DOWN in server master from #{inspect wpid}"
                IO.inspect msg
                Process.exit(wpid, :kill)
                send self, {:start_mining, k, work_unit_size, 1}
                master(workers_count-1, k, ppid, qip, work_unit_size)
        end
    end

    def worker do
        receive do
            {:mine_coins, k, work_unit_size, mpid} ->
                #IO.puts "server worker #{inspect self} received mine_coins"
                mined_coins_list = Bitcoinminer.main(k, work_unit_size)
                #IO.puts "server worker #{inspect self} sends mined coins to master"
                send mpid, {:collect_mined_coins, mined_coins_list}
                send self, {:mine_coins, k, work_unit_size, mpid}
            end
        worker
    end
    
    def printer do
        receive do
            {:print_mined_coins, mined_coins_list} ->
                #IO.puts "printer received print_mined_coins"
                Enum.each(mined_coins_list, fn(coin) -> IO.puts(coin) end)
            end
        printer
    end

    def client_work_assigner(k, work_unit_size) do
        receive do
            {:receive_work, mined_coins_list} ->
                #IO.puts "client_work_assigner received receive_work"
                Enum.each(mined_coins_list, fn(coin) -> IO.puts(coin) end)
            {:assign_work, gpid} ->
                #IO.puts "client_work_assigner received assign_work"
                :global.sync
                send gpid, {:work_received, k, work_unit_size}
        end
        client_work_assigner(k, work_unit_size)
    end
end
