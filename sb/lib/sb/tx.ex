defmodule SB.Tx do
  @moduledoc false

  defstruct txid: nil, amount: 0, signature: nil, version: nil, tx_in_count: nil, tx_in: [], tx_out_count: nil, tx_out: [], lock_time: nil, public_key: nil

end
