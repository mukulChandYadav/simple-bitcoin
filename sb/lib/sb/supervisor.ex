defmodule SB.Supervisor do
  use Supervisor

  require Logger

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, [])
  end

  def init(args) do
    Logger.debug("Inside init " <> inspect(__MODULE__) <> " " <> "with args: " <> inspect(args))

    children = [
      {Registry, keys: :unique, name: SB.Registry.Miners},
      {Registry, keys: :unique, name: SB.Registry.TransactionRepo},
      {Registry, keys: :unique, name: SB.Registry.NodeInfo},
      {SB.Master, name: SB.Master},
      {DynamicSupervisor, name: SB.NodeSupervisor, strategy: :one_for_one},
      {Task.Supervisor, name: SB.MiningTaskSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
