defmodule SBTest do
  use ExUnit.Case
  doctest SB

  require Logger
  use ExUnit.Case, async: true

  setup do
    Logger.debug("Inside test setup ")
  end

  @tag timeout: 100000000
  test "start network" do
    perform_test
  end


  defp perform_test() do
    #GenServer.call(SB.Master, {:init, []}, :infinity)
    assert true
  end

end