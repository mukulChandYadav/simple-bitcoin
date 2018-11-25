defmodule SB.Node do
  @moduledoc false


  use GenServer

  def start_link(state, opts) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(opts) do

    node_state = %SB.NodeInfo{node_id: self, is_miner: opts.is_miner}
    if(opts.is_miner)  do
      Registry.register(SB.Registry.Miners, self, node_state)
    end

    {:ok, node_state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end



  def handle_cast({:verify_block, block}, state) do
    {:noreply, state}
  end

  def handle_cast({:new_block_registered, block}, state) do
    {:noreply, state}
  end

  ##TODO: Add block approval by all miners logic

  defp mine() do



  end

  def perform_tx() do

  end

  def listen() do

  end
  
end
