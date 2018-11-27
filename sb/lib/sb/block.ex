defmodule SB.Block do
  @moduledoc false

  defstruct version: 1 , timestamp: nil, target: nil, nonce: 0, prevHash: nil, tx: [], block_id: 0

end
