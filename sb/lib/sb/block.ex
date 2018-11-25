defmodule SB.Block do
  @moduledoc false

  defstruct version: 1 , timestamp: nil, target: nil, nonce: nil, prevHash: nil, tx: []

end
