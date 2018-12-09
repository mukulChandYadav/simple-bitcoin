defmodule SB.Node do
  @moduledoc false


  use GenServer

  use GenEvent

  require Logger


  #TODO:

  #  def start_link(state, opts) do
  #    #####Logger.debug("Inside #{inspect __MODULE__} Node start_link of #{inspect self}")
  #    GenServer.start_link(__MODULE__, state, opts)
  #  end

  def start_link(opts) do
    #####Logger.debug("Inside #{inspect __MODULE__} Node start_link with opts - #{inspect opts}")
    ret_val = GenServer.start_link(__MODULE__, opts)
    #####Logger.debug("Inside #{inspect __MODULE__} ret val - #{inspect ret_val}")

    # Add transaction publish handler
    {:ok, pid} = GenEvent.start([])
    GenEvent.add_handler(pid, SB.Node, [])

    ret_val
  end

  def init(opts) do

    #####Logger.debug("Inside #{inspect __MODULE__} Node init of #{inspect self} with opts - #{inspect opts}")

    is_miner = Map.get(opts, :is_miner)
    #####Logger.debug("Inside #{inspect __MODULE__} node state -  and is_miner - #{inspect is_miner}")

    secret_key = SB.CryptoHandle.generate_private_key()
    public_key = SB.CryptoHandle.generate_public_key(secret_key)

    ## TODO  Implement a way to retrieve current active block from network
    node_state = %SB.NodeInfo{node_id: self, is_miner: is_miner, block: %SB.Block{}, secret_key: secret_key, public_key: public_key}

    if(is_miner == true) do
      #####Logger.debug("Inside #{inspect __MODULE__} miner true block")
      add_miner(node_state.node_id)
      #Registry.register(SB.Registry.NodeInfo, node_state.node_id, %{nonce: 0})
      :ets.insert(:ets_mine_jobs, {%{node_id: node_state.node_id, val: :nonce}, 0})
    end

    {:ok, wallet_pid} = GenServer.start_link(SB.Wallet, %{secret_key: secret_key, public_key: public_key, owner_pid: self()})

    #Logger.error("wallet -#{inspect  GenServer.call(wallet_pid, :get_state_info)}")
    {:ok, wallet_state} = GenServer.call(wallet_pid, :get_state_info)
    node_state = put_in(node_state.wallet, wallet_state)
    #send(self, :mine)
    #####Logger.debug("Inside #{inspect __MODULE__} Node state - #{inspect node_state} for #{inspect self}")
    {:ok, node_state}
  end

  # Process new transaction published handler for miners
  def handle_event({:new_transaction, tx}, state) do
    Logger.debug "Received new transaction message: '#{inspect tx}'"
    #Invoke block chain creation process
    send(self, {:mine, tx})
    {:ok, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_info({:mine, tx_to_be_processed}, state) do
    ##Logger.debug("Inside #{inspect __MODULE__} Mine block Node state - #{inspect state}")

    #TODO Add generated blocks to owner nodes
    num_blocks_mined = length(state.wallet.blocks)
    Logger.debug("Inside #{inspect __MODULE__} Num blocks mined by #{inspect state.node_id} node is - #{inspect num_blocks_mined}")

    #TODO: Add new transaction to new block
    new_tx = nil

    if(num_blocks_mined < 3) do
      block_header_hash = ""
      curr_nonce =
        try do
          [{_, curr_nonce}] = :ets.lookup(:ets_mine_jobs, %{node_id: state.node_id, val: :nonce})
          #Registry.lookup(SB.Registry.NodeInfo, %{node_id: state.node_id, val: :nonce})
          curr_nonce
        rescue
          e in [MatchError] ->
            %{nonce: 0}
        end
      mining_task = Task.Supervisor.async(SB.MiningTaskSupervisor, SB.Node, :mine, [4, block_header_hash, state.block, self, curr_nonce, new_tx])

      add_task_to_table(mining_task.pid, state)

    else
      if(tx_to_be_processed != nil)do
        block_header_hash = "" #TODO
        curr_nonce =
          try do
            [{_, curr_nonce}] = :ets.lookup(:ets_mine_jobs, %{node_id: state.node_id, val: :nonce})
            #Registry.lookup(SB.Registry.NodeInfo, %{node_id: state.node_id, val: :nonce})
            curr_nonce
          rescue
            e in [MatchError] ->
              %{nonce: 0}
          end

        mining_task = Task.Supervisor.async(SB.MiningTaskSupervisor, SB.Node, :mine, [4, block_header_hash, state.block, self, curr_nonce, new_tx])

        add_task_to_table(mining_task.pid, state)
      end
    end

    #####Logger.debug("Inside #{inspect __MODULE__} End of mine block for Node state - #{inspect state} for #{inspect self}")
    {:noreply, state}
  end


  def handle_info(_msg, state) do
    ####Logger.debug("Inside #{inspect __MODULE__} default info handler m-#{inspect _msg} s-#{inspect _state}")
    {:noreply, state}
  end

  def handle_cast({:verify_block, new_block}, state) do

    ###Logger.debug("Inside #{inspect __MODULE__} verify block cast handler m-#{inspect block} on node-#{inspect state.node_id}")
    is_block_valid = verify_block?(new_block, state.block)
    if(is_block_valid) do
      add_to_repo(new_block, self)
    else

    end
    {:noreply, state}
  end


  def handle_cast({:new_block_registered, block}, state) do
    ##Logger.debug("#{inspect __MODULE__} Approved block - #{inspect block} received by #{inspect state}")

    new_state = %{state | block: block}

    out = :ets.lookup(:ets_mine_jobs, %{node_id: self, tran_num: length state.block.tx})
    ###Logger.debug("#{inspect __MODULE__} Get Mine jobs #{inspect out} for #{inspect self} ")
    mine_job = if(out == [] || out == nil) do
      out
    else
      [{_, list}] = out
      list
    end

    #TODO Add to wallet if it corresponds to this node
    new_state = update_wallet(new_state)

    block_ids = Enum.map(new_state.wallet.blocks, fn x -> x.block_id end)
    Logger.debug("Inside #{inspect __MODULE__} New block registered after Update wallet of #{inspect state.node_id}. After update blocks in wallet - #{inspect block_ids}")

    if(Process.alive?(mine_job)) do
      ###Logger.debug("Inside #{inspect __MODULE__} Killing mine job - #{inspect mine_job} of node - #{inspect self}")
      Process.exit(mine_job, :normal)
    end

    #Delete the processed transaction from queue
    purge_old_tx(block.tx)

    # Trigger next mine operation
    ##Logger.debug("Inside #{inspect __MODULE__} Trigger next mine operation using block - #{inspect block}")
    new_tx_to_process = get_new_transaction_from_queue()
    Task.async(__MODULE__, :schedule_work_after, [{:mine, new_tx_to_process}, self, 1000])
    {:noreply, new_state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  defp purge_old_tx(tx) do
    out = :ets.lookup(:ets_trans_repo, :new_tranx)
    ####Logger.debug("#{inspect __MODULE__} Get Miners : #{inspect out} ")
    map = if(out == nil) do
      %{}
    else
      [{_, map}] = out
      map
    end
    :ets.insert(:ets_trans_repo, {:new_tranx, Map.delete(map, tx.id)})
  end

  defp get_new_transaction_from_queue() do
    get_new_transaction_from_queue(nil)
  end

  defp get_new_transaction_from_queue(tx) do

    out = :ets.lookup(:ets_trans_repo, :new_tranx)
    ####Logger.debug("#{inspect __MODULE__} Get Miners : #{inspect out} ")
    map = if(out == nil) do
      out
    else
      [{_, map}] = out
      map
    end

    keys = Map.keys(map)

    queued_tx =
      if(tx! = nil)do
        if(keys! = []) do
          Map.get(map, tx.id)
        else
          nil
        end
      else
        if(keys! = []) do
          Map.get(map, keys[0])
        else
          nil
        end
      end

  end

  def mine(leading_zeros, hash_msg, base_block, parent_pid, nonce, new_tx) do #TODO Remove hash_msg arg
    hash_msg = if(base_block.prev_block == nil) do
      ""
    else
      SB.CryptoHandle.encoded_hash(inspect(base_block.block_header), :sha256)
    end

    msgt = hash_msg <> to_string(nonce)
    temp = :crypto.hash(:sha256, msgt)
           |> Base.encode16()
           |> String.downcase()
    #IO.inspect(temp)

    if(String.slice(temp, 0, leading_zeros) === String.duplicate("0", leading_zeros)) do
      #IO.inspect(String.slice(temp, 0, leading_zeros) === String.duplicate("0", leading_zeros))

      new_block = SB.Block.prepare_block(base_block, nonce, new_tx)

      :ets.insert(:ets_mine_jobs, {%{node_id: parent_pid, val: :nonce}, nonce})
      :ets.insert(:ets_mine_jobs, {%{node_id: parent_pid, val: :block, id: new_block.block_id}, new_block})

      #Logger.debug("Inside #{inspect __MODULE__} mine. Node - #{inspect parent_pid} mined this block - #{inspect new_block}")
      #abc = :ets.lookup(:ets_mine_jobs, %{node_id: parent_pid, val: :block, id: new_block.block_id})
      #Registry.lookup(SB.Registry.NodeInfo, %{node_id: parent_pid, val: :block, id: new_block.block_id})
      #Logger.debug("Inside #{inspect __MODULE__} mine. Registered block - #{inspect abc}")


      # Ask each miner to verify block
      miners = get_miners()
      for x <- miners do
        if(x != parent_pid) do
          GenServer.cast(x, {:verify_block, new_block})
        end
      end

    else
      mine(leading_zeros, hash_msg, base_block, parent_pid, nonce + 1, new_tx)
    end
  end

  defp update_wallet(new_state) do
    Logger.debug("Inside #{inspect __MODULE__} Update wallet. Received block - #{inspect new_state.block.block_id} for verification to #{inspect new_state.node_id}")

    block_mined_by_this_node_with_new_block_id =
      try do
        [{_, mined_block}] = :ets.lookup(:ets_mine_jobs, %{node_id: new_state.node_id, val: :block, id: new_state.block.block_id})
        mined_block
      rescue
        e in [MatchError] ->
          nil
      end

    #Logger.debug("Inside #{inspect __MODULE__} Update wallet. Block mined by #{inspect new_state.node_id} node - #{inspect block_mined_by_this_node_with_new_block_id}")

    # Relying on timestamp for confirming that approved block is mined by this node
    #TODO Revert to signature verification later
    new_state = if ((block_mined_by_this_node_with_new_block_id != nil) && (new_state.block.timestamp == block_mined_by_this_node_with_new_block_id.timestamp)) do
      Logger.debug("Inside #{inspect __MODULE__} Update wallet. #{inspect new_state.node_id} node #{inspect new_state.node_id} mined this-#{inspect new_state.block.block_id} block.")
      new_state = %{new_state | wallet: SB.Wallet.update_wallet_with_block(new_state.wallet, new_state.block)}
      :ets.delete(:ets_mine_jobs, %{node_id: new_state.node_id, val: :block, id: new_state.block.block_id})
      new_state
    else
      Logger.debug("Inside #{inspect __MODULE__} Update wallet. #{inspect new_state.node_id} node #{inspect new_state.node_id} did not mine this-#{inspect new_state.block.block_id} block")
      new_state
    end
    new_state
  end

  defp add_to_repo(block, miner_id) do
    block_hash = SB.CryptoHandle.hash(inspect(block), :sha256)
    miner_approvers_list_out = :ets.lookup(:ets_trans_repo, block_hash)

    ###Logger.debug("#{inspect __MODULE__} Miner approver list - #{inspect miner_approvers_list_out} for block #{inspect block_hash} ")
    miner_approvers_list = if(miner_approvers_list_out == []) do
      miner_approvers_list_out
    else
      [{_, list}] = miner_approvers_list_out
      list
    end

    updated_list = List.insert_at(miner_approvers_list, -1, miner_id)
    :ets.insert(:ets_trans_repo, {block_hash, updated_list})

    if(length(updated_list) >= 2) do # NUM MINERS end
      miners = get_miners()
      ##Logger.debug("#{inspect __MODULE__} approver threshold crossed approved miner list- #{inspect miners} for block #{inspect block_hash} ")
      for miner <- miners do
        if(Process.alive?(miner)) do # Safety net
          GenServer.cast(miner, {:new_block_registered, block})
        end
      end
    end
  end

  def get_miners() do

    out = :ets.lookup(:ets_miners, :miners)
    ####Logger.debug("#{inspect __MODULE__} Get Miners : #{inspect out} ")
    list = if(out == []) do
      out
    else
      [{_, list}] = out
      list
    end

    ####Logger.debug("Inside #{inspect __MODULE__} get miners raw list #{inspect list}")
    list
  end

  defp add_miner(miner_id) do
    miner_list = get_miners()
    updated_list = List.insert_at(miner_list, -1, miner_id)
                   |> List.flatten
    :ets.insert(:ets_miners, {:miners, updated_list})

    ####Logger.debug("Inside #{inspect __MODULE__} add miners updated list - #{inspect updated_list}")
  end

  defp add_task_to_table(mining_task_pid, state) do
    :ets.insert(:ets_mine_jobs, {%{node_id: state.node_id, tran_num: length state.block.tx}, mining_task_pid})
  end

  defp verify_block?(new_block, current_block) do
    #TODO Implement
    is_valid = if((new_block.block_id > current_block.block_id) || (current_block.block_id == 0)) do
      true
    else
      false
    end
    is_valid
  end

  defp verify_tx?(tx) do
    #TODO Implement
    true
  end

  def schedule_work_after(job_message, pid, time_interval) do
    ###Logger.debug("Before schedule #{inspect self()}")
    Process.sleep(time_interval)
    #message_timer = Process.send_after(self(), job_message, time_interval)
    send(pid, job_message)
    ###Logger.debug("After schedule #{inspect self()}")
    # # ###Logger.debug("Message timer #{inspect job_atom_id} for self: #{inspect Process.read_timer(message_timer)}")
  end


  def handle_call({:perform_transaction, tx}, state) do
    #TODO
    GenServer.call(state.wallet.wallet_pid, {:create_transaction, tx})
    {:reply, :ok, state}
  end


end
