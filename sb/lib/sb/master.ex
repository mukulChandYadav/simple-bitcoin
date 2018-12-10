defmodule SB.Master do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(opts) do
    Logger.debug("Inside #{inspect(__MODULE__)} start_link with opts - #{inspect(opts)}")
    return_val = GenServer.start_link(__MODULE__, :ok, opts)

    Logger.debug(
      "Inside #{inspect(__MODULE__)} GenServer start return val #{inspect(return_val)}"
    )

    return_val
  end

  def init(opts) do
    Logger.debug("Inside #{inspect(__MODULE__)} init with opts - #{inspect(opts)}")
    # send(self, :init)
    miners_table = :ets.new(:ets_miners, [:public, :set, :named_table])
    trans_table = :ets.new(:ets_trans_repo, [:public, :set, :named_table])
    mine_job_table = :ets.new(:ets_mine_jobs, [:public, :set, :named_table])
    wallet_address_table = :ets.new(:ets_wallet_addrs, [:public, :set, :named_table])

    {:ok, %{}}
  end

  def handle_info(:init, _from, state) do
    Logger.debug("Inside #{inspect(__MODULE__)} init")
    init_network()

    {:reply, :ok, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def init_network() do
    Logger.debug("Inside #{inspect(__MODULE__)}  init network")

    # 8
    num_miners = 3

    for x <- 1..num_miners do
      {:ok, node_pid} =
        DynamicSupervisor.start_child(SB.NodeSupervisor, {SB.Node, %{is_miner: true, node_id: x}})

      Logger.debug("Inside #{inspect(__MODULE__)}  Miner - #{inspect(node_pid)}")
      send(node_pid, {:mine, nil})
    end

  end
end
