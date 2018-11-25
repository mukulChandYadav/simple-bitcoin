defmodule SB do
  use Application

  require Logger

  @moduledoc """
  Documentation for SB.
  """

  def start(type, args) do
    #Logger.debug("Inside start " <> inspect(__MODULE__) <> " " <> "with args: " <> inspect(args) <> "and type: " <> inspect(type))
    SB.Supervisor.start_link(args)
    GenServer.call(SB.Master, {:process, args}, :infinity)
  end

end
