defmodule SB.Master do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(opts) do
    Logger.debug("Inside #{inspect __MODULE__} start_link with opts - #{inspect opts}")
    return_val = GenServer.start_link(__MODULE__, :ok, opts)
    Logger.debug("Inside #{inspect __MODULE__} GenServer start return val #{inspect return_val}")
    return_val
  end

  def init(opts) do
    Logger.debug("Inside #{inspect __MODULE__} init with opts - #{inspect opts}")
    #send(self, :init)

    {:ok, %{}}
  end

  def handle_info(:init, _from, state) do
    Logger.debug("Inside #{inspect __MODULE__} init")
    init_network

    {:reply, :ok, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def init_network() do
    Logger.debug("Inside #{inspect __MODULE__}  init network")

    for x <- 1..8 do
      {:ok, node_pid} =
        DynamicSupervisor.start_child(SB.NodeSupervisor, {SB.Node, %{is_miner: true}})
      Logger.debug("Inside #{inspect __MODULE__}  Miner - #{inspect node_pid}")
    end

    Process.sleep(1000000000)
  end

end
