defmodule Client do

    def connect(server_ip) do
        # Retrieve the fully qualified client node ip
        {ok, [{ip_comma, gateway,subnet}, {_,_,_}]} = :inet.getif 
        ip = :inet.ntoa(ip_comma)
        {ok, hname} = :inet.gethostname       
        qip = to_string(hname) <> "@" <> to_string(ip)

        # Start the client node and set cookie
        unless Node.alive?() do
            Node.start(String.to_atom(qip))
        end

        Node.set_cookie(Node.self, :"chocolate-chip")
         
        case Node.connect(String.to_atom("project@" <> server_ip)) do
            true -> :ok
            reason ->
                IO.puts "Could not connect to server_ip, reason: #{reason}"
                System.halt(0)
        end
        
        # Set the workers_count
        workers_count = System.schedulers_online
        
        # Spawn master, receive_work, report_work and get_work processes on client node
        rpid = Node.spawn_link(String.to_atom(qip),Client, :report_work, [server_ip])
        rwpid = Node.spawn_link(String.to_atom(qip),Client, :receive_work,[rpid])        
        mpid = Node.spawn_link(String.to_atom(qip),Client, :master, [workers_count, rwpid, qip])
        gpid = Node.spawn_link(String.to_atom(qip),Client, :get_work, [mpid,workers_count])
		
        # Send request_work message to master process
        send gpid, {:request_work}

        # Trap exit errors from client spawned processes  
        Process.flag(:trap_exit, true)
        receive do
            {:EXIT, pid, :normal} ->
                IO.inspect "Normal exit in client from #{inspect pid}"
            {:EXIT, pid, msg} ->
                IO.inspect ":EXIT received in client from #{inspect pid}"
                IO.inspect msg
        end
    end

    def master(workers_count, rwpid, qip) do
        receive do
            {:start_mining, k, work_unit_size, workers_count} ->
                if workers_count > 0 do
                    wpid = Node.spawn(String.to_atom(qip), Client, :worker, [])
                    ref = Process.monitor(wpid)
                    #IO.puts "send mine_coins to worker process #{inspect wpid}"
                    send wpid, {:mine_coins, k, work_unit_size, self()}
                    workers_count = workers_count - 1
                    send self, {:start_mining, k, work_unit_size, workers_count}
                end
            master(workers_count,rwpid, qip)
            {:collect_mined_coins, mined_coins_list} ->
                #IO.puts "received collect_mined_coins message"
                send rwpid, {:report_mined_coins, mined_coins_list}
                master(workers_count, rwpid, qip)
            {:DOWN, ref, :process, wpid, :normal} ->
                IO.puts "Normal exit in master from #{inspect wpid}"
                master(workers_count-1,rwpid, qip)
            {:DOWN, ref, :process, wpid, msg} ->
                IO.puts "Received :DOWN in master from #{inspect wpid}"
                IO.inspect msg
                Process.exit(wpid, :kill)
                send self, {:start_mining, :ets.lookup_element(:parameters,:zeros, 2), :ets.lookup_element(:parameters,:work_size,2), 1}
                master(workers_count-1, rwpid, qip)
        end     
    end

    def worker do
        receive do
            {:mine_coins, k, work_unit_size, mpid} ->
                #IO.puts "client worker #{inspect self} received mine_coins"
                mined_coins_list = Bitcoinminer.main(k, work_unit_size)
                #IO.puts "client worker #{inspect self} sends mined coins to master"
                send mpid, {:collect_mined_coins, mined_coins_list}
                send self, {:mine_coins, k, work_unit_size, mpid}
        end
        worker
    end
    
    def receive_work(rpid) do
        receive do
            {:report_mined_coins, mined_coins_list} ->
                #IO.puts "receive_work received report_mined_coins"
                send rpid, {:report, mined_coins_list}
        end
        receive_work(rpid)
    end
        
    def report_work(rpid) do
        receive do
            {:report, mined_coins_list} ->
                #IO.puts "report_work received report mined coins to assigner of server"    
                send :global.whereis_name(:client_work_assignerid), {:receive_work, mined_coins_list}
        end
        report_work(rpid)
    end
    
    def get_work(mpid, workers_count) do
        receive do
            {:request_work} ->
                :global.sync
                #IO.puts "get_work received request_work #{inspect :global.whereis_name(:client_work_assignerid)}"
                send :global.whereis_name(:client_work_assignerid),{:assign_work, self()}
            {:work_received, k, work_unit_size} ->
                #IO.puts "get_work received work_received from assigner of server"
                :ets.new(:parameters, [:named_table, read_concurrency: true])
                :ets.insert(:parameters, {:zeros,k})
                :ets.insert(:parameters, {:work_size,work_unit_size})
                send mpid, {:start_mining, k, work_unit_size, workers_count}
        end
        get_work(mpid,workers_count)
    end
end


