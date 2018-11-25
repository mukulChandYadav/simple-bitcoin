defmodule SBTest do
  use ExUnit.Case
  doctest SB

  test "greets the world" do
    assert SB.hello() == :world
  end
end
