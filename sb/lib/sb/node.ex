defmodule SB.Node do
  @moduledoc false


  use GenServer
  require Logger

  def start_link(state, opts) do
    ###Logger.debug("Inside #{inspect __MODULE__} Node start_link of #{inspect self}")
    GenServer.start_link(__MODULE__, state, opts)
  end

  def start_link(opts) do
    ###Logger.debug("Inside #{inspect __MODULE__} Node start_link with opts - #{inspect opts}")
    ret_val = GenServer.start_link(__MODULE__, opts)
    ###Logger.debug("Inside #{inspect __MODULE__} ret val - #{inspect ret_val}")
    ret_val
  end

  def init(opts) do

    ###Logger.debug("Inside #{inspect __MODULE__} Node init of #{inspect self} with opts - #{inspect opts}")

    is_miner = Map.get(opts, :is_miner)
    ###Logger.debug("Inside #{inspect __MODULE__} node state -  and is_miner - #{inspect is_miner}")
    node_state = %SB.NodeInfo{node_id: self, is_miner: is_miner, block: %SB.Block{}}

    if(is_miner == true)  do
      ###Logger.debug("Inside #{inspect __MODULE__} miner true block")
      addMiner(node_state.node_id)
      Registry.register(SB.Registry.NodeInfo, node_state.node_id, %{nonce: 0})
    end
    #send(self, :mine)
    ###Logger.debug("Inside #{inspect __MODULE__} Node state - #{inspect node_state} for #{inspect self}")
    {:ok, node_state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end


  def handle_info(:mine, state) do
    ##Logger.debug("Inside #{inspect __MODULE__} Mine block Node state - #{inspect state}")
    num_blocks_mined = length(state.wallet.blocks)

    if(num_blocks_mined < 10) do
      block_header_hash = ""
      [{_, curr_nonce}] = Registry.lookup(SB.Registry.NodeInfo, state.node_id)
      miningTask = Task.Supervisor.async(SB.MiningTaskSupervisor, SB.Node, :mine, [4, block_header_hash, state.block, self, curr_nonce.nonce])

      addTaskToTable(miningTask.pid, state)

    end

    ###Logger.debug("Inside #{inspect __MODULE__} End of mine block for Node state - #{inspect state} for #{inspect self}")
    {:noreply, state}
  end


  def handle_info(_msg, state) do
    ##Logger.debug("Inside #{inspect __MODULE__} default info handler m-#{inspect _msg} s-#{inspect _state}")
    {:noreply, state}
  end

  def handle_cast({:verify_block, block}, state) do

    #Logger.debug("Inside #{inspect __MODULE__} verify block cast handler m-#{inspect block} on node-#{inspect state.node_id}")
    is_block_valid = verify_block?(block)
    if(is_block_valid) do
      addToRepo(block, self)
    else

    end

    {:noreply, state}
  end

  defp addToRepo(block, miner_id) do
    block_hash = SB.CryptoHandle.hash(inspect(block), :sha256)
    miner_approvers_list_out = :ets.lookup(:ets_trans_repo, block_hash)

    #Logger.debug("#{inspect __MODULE__} Miner approver list - #{inspect miner_approvers_list_out} for block #{inspect block_hash} ")
    miner_approvers_list = if(miner_approvers_list_out == []) do
      miner_approvers_list_out
    else
      [{_, list}] = miner_approvers_list_out
      list
    end

    updated_list = List.insert_at(miner_approvers_list, -1, miner_id)
    :ets.insert(:ets_trans_repo, {block_hash, updated_list})

    if(length(updated_list) >= 7) do
      miners = getMiners()
      Logger.debug("#{inspect __MODULE__} approver threshold crossed approved miner list- #{inspect miners} for block #{inspect block_hash} ")
      for miner <- miners do
        if(Process.alive?(miner)) do # Safety net
          GenServer.cast(miner, {:new_block_registered, block})
        end
      end
    end
  end

  defp verify_block?(block) do
    #TODO Implement
    true
  end


  def handle_cast({:new_block_registered, block}, state) do
    Logger.debug("#{inspect __MODULE__} Approved block - #{inspect block} received by #{inspect state}")

    new_state = %{state | block: block}

    out = :ets.lookup(:ets_mine_jobs, %{node_id: self, tran_num: length state.block.tx})
    Logger.debug("#{inspect __MODULE__} Get Mine jobs #{inspect out} for #{inspect self} ")
        mine_job = if(out == [] || out == nil) do
          out
        else
          [{_, list}] = out
          list
        end

    if(Process.alive?(mine_job)) do
      Process.exit(mine_job, :normal)
    end

    # Trigger next mine operation
    Logger.debug("Inside #{inspect __MODULE__} Trigger next mine operation using block - #{inspect block}")
    send(self, :mine)
    {:noreply, new_state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end


  def mine(leading_zeros, hash_msg, block, parent_pid, nonce) do
    msgt = hash_msg <> to_string(nonce)
    temp = :crypto.hash(:sha256, msgt)
           |> Base.encode16()
           |> String.downcase()
    #IO.inspect(temp)

    if(String.slice(temp, 0, leading_zeros) === String.duplicate("0", leading_zeros)) do
      IO.inspect(String.slice(temp, 0, leading_zeros) === String.duplicate("0", leading_zeros))
      new_block_id = block.block_id + 1
      block_ts = :os.system_time(:millisecond)
      new_block = %{block | timestamp: block_ts}
      new_block = %{new_block | nonce: nonce}
      new_block = %{new_block | prevHash: hash_msg}
      new_block = %{new_block | block_id: new_block_id}
      #TODO: Add new transaction to new block
      Registry.register(SB.Registry.TransactionRepo, new_block.block_id, new_block)
      Registry.register(SB.Registry.NodeInfo, parent_pid, %{nonce: nonce})

      # Ask each miner to verify block
      miners = getMiners()
      for x <- miners do
        if(x != parent_pid) do
          GenServer.cast(x, {:verify_block, new_block})
        end
      end

      #Enum.each(miners, fn x -> GenServer.cast(x, {:verify_block, new_block}) end)

    else
      mine(leading_zeros, hash_msg, block, parent_pid, nonce + 1)
    end
  end

  defp getMiners() do

    out = :ets.lookup(:ets_miners, :miners)
    ##Logger.debug("#{inspect __MODULE__} Get Miners : #{inspect out} ")
    list = if(out == []) do
      out
    else
      [{_, list}] = out
      list
    end

    ##Logger.debug("Inside #{inspect __MODULE__} get miners raw list #{inspect list}")
    list
  end

  defp addMiner(miner_id) do
    miner_list = getMiners()
    updated_list = List.insert_at(miner_list, -1, miner_id)
                   |> List.flatten
    :ets.insert(:ets_miners, {:miners, updated_list})

    ##Logger.debug("Inside #{inspect __MODULE__} add miners updated list - #{inspect updated_list}")
  end


  defp addTaskToTable(miningTaskPid, state) do
    :ets.insert(:ets_mine_jobs, {%{node_id: state.node_id, tran_num: length state.block.tx}, miningTaskPid})
  end

end
