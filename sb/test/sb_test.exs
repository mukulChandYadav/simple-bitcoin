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
    perform_test()
    perform_tx_test()
  end

  defp perform_test() do
    SB.Master.init_network()
    Process.sleep(1000000000);
    assert true
  end

  defp perform_tx_test() do
    Process.sleep(1000000000);
    assert true
  end

end