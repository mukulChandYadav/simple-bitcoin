defmodule SB.Node do
  @moduledoc false


  use GenServer
  require Logger

  def start_link(state, opts) do
    Logger.debug("Inside #{inspect __MODULE__} Node start_link of #{inspect self}")
    GenServer.start_link(__MODULE__, state, opts)
  end

  def start_link(opts) do
    Logger.debug("Inside #{inspect __MODULE__} Node start_link with opts - #{inspect opts}")
    ret_val = GenServer.start_link(__MODULE__, opts)
    Logger.debug("Inside #{inspect __MODULE__} ret val - #{inspect ret_val}")
    ret_val
  end

  def init(opts) do

    Logger.debug("Inside #{inspect __MODULE__} Node init of #{inspect self} with opts - #{inspect opts}")

    is_miner = Map.get(opts, :is_miner)
    Logger.debug("Inside #{inspect __MODULE__} node state -  and is_miner - #{inspect is_miner}")
    node_state = %SB.NodeInfo{node_id: self, is_miner: is_miner}


    if(is_miner == true)  do
      Logger.debug("Inside #{inspect __MODULE__} miner true block")
      Registry.register(SB.Registry.Miners, :miner, node_state)
    end
    send(self, :mine)
    Logger.debug("Inside #{inspect __MODULE__} Node state - #{inspect node_state} for #{inspect self}")
    {:ok, node_state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end


  def handle_cast(:mine, state) do
    num_blocks_mined = length(state.wallet.blocks)

    if(num_blocks_mined < 10) do
      block_header_hash = ""
      [{_, curr_nonce}] = Registry.lookup(SB.Registry.NodeInfo, state.node_id)
      miningTask = Task.Supervisor.async(SB.MiningTaskSupervisor, SB.Node, :mine, [4, block_header_hash, state.block, self, curr_nonce])
    end

    {:noreply, state}
  end

  def handle_cast({:verify_block, block}, state) do


    ##TODO: Check if block is verified by all miners, then cast new block registered call
    ##TODO: Add block approval by all miners logic
    ## GenServer.cast({:new_block_registered, block})
    {:noreply, state}
  end

  def handle_cast({:new_block_registered, block}, state) do
    #TODO Update block pointer of this node to approved block

    #TODO Kill any mining job started by this node on block.prevHash block
    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end


  defp mine(leading_zeros, hash_msg, block, parent_pid, nonce) do
    msgt = hash_msg <> to_string(nonce)
    temp = :crypto.hash(:sha256, msgt)
           |> Base.encode16()
           |> String.downcase()
    IO.inspect(temp)

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
      Registry.register(SB.Registry.NodeInfo, parent_pid, nonce)

      # Ask each miner to verify block
      miners = getMiners()
      Enum.each(miners, fn x -> GenServer.cast(x, {:verify_block, new_block}) end)

      # Wait for block commit to finish
      Process.sleep(2000)
      # Trigger next mine operation
      GenServer.cast(parent_pid, :mine)
    else
      mine(leading_zeros, hash_msg, block, parent_pid, nonce + 1)
    end
  end

  def perform_tx() do

  end

  def listen() do

  end

  defp getMiners() do
    list = Registry.lookup(SB.Registry.Miners, "miners")
    Enum.map(list, fn x -> {_, miner_pid} = x; miner_pid end)
  end

end
