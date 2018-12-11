defmodule SB.Wallet do
  @moduledoc false

  use GenServer

  require Logger
  # TODO: Add cryptographic functionalities

  def start_link(state, opts) do
    ##### Logger.debug("Inside #{inspect __MODULE__} Node start_link of #{inspect self}")
    GenServer.start_link(__MODULE__, state, opts)
  end

  def start_link(opts) do
    ##### Logger.debug("Inside #{inspect __MODULE__} Node start_link with opts - #{inspect opts}")
    ret_val = GenServer.start_link(__MODULE__, opts)
    ##### Logger.debug("Inside #{inspect __MODULE__} ret val - #{inspect ret_val}")
    ret_val
  end

  def init(opts) do
    Logger.debug("Called with  - #{inspect(opts)}")

    wallet_state = %SB.WalletInfo{
      secret_key: opts.secret_key,
      public_key: opts.public_key,
      owner_pid: opts.owner_pid,
      wallet_pid: self(),
      owner_id: opts.owner_id
    }

    # TODO Initialize wallet state from static file
    prefix = "76A914"
    suffix = "88AC"
    wallet_addr = prefix <> SB.CryptoHandle.generate_public_hash_hex(opts.public_key) <> suffix
    :ets.insert(:ets_wallet_addrs, {wallet_addr, self()})

    {:ok, wallet_state}
  end

  def handle_call(:get_state_info, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:get_pub_key, _from, state) do
    {:reply, {:ok, state.public_key}, state}
  end

  def handle_call({:update_wallet_receiver, tx}, _from, state) do
    SB.Tx.update_utxo_json(:receiver, state.owner_id, tx)

    {:reply, :ok, state}
  end

  def handle_call({:update_wallet_sender, tx}, _from, state) do
    SB.Tx.update_utxo_json(:sender, state.owner_id, tx)

    {:reply, :ok, state}
  end

  def create_utxos(utxos, _, _, remaining_amount) when remaining_amount <= 0 do
    utxos
  end

  def create_utxos(utxos, utxos_map, utxo_keys, key_index, remaining_amount) do
    {:ok, key} = Enum.fetch(utxo_keys, key_index)
    Logger.debug("Key for utxo: " <> inspect(key))
    utxo = utxos_map[key]
    # Map.get(utxos_map, key)

    # out_index_key = Map.keys(utxo) |> List.first()
    # Logger.debug("Key for utxo: " <> inspect(out_index_key))
    # utxos = utxos ++ [utxo[out_index_key]]
    # Logger.debug("utxos: " <> inspect(utxos))
    # utxo_values = utxo[out_index_key]
    # Logger.debug("UTXO value: " <> inspect(utxo_values))
    # utxo_amount = utxo_values["value"] |> String.to_integer(16)

    utxos ++ [utxos_map]
    # create_utxos(utxos, utxos_map, utxo_keys, key_index + 1, remaining_amount - utxo_amount)
  end

  def handle_call(:get_balance, _from, state) do
    balance = 0
    node_id = state.owner_id

    path = Path.absname("./lib/data/")
    # Logger.debug(inspect(__MODULE__) <> "Dir path: " <> inspect(path))
    filename = inspect(node_id) <> "utxo" <> ".json"

    {:ok, utxos_map} =
      (path <> "/" <> filename)
      |> SB.Tx.get_json()

    # utxo_keys = Map.keys(utxos_map)

    balance =
      Enum.reduce(utxos_map, 0, fn {_, utxo}, acc ->
        transaction_balance =
          Enum.reduce(utxo, 0, fn {_, out_index_map}, sum ->
            amount = out_index_map["value"] |> String.to_integer(16)
            sum + amount
          end)

        acc + transaction_balance
      end)

    # Logger.debug("Balance: " <> inspect(balance))
    {:reply, {:ok, balance}, state}
  end

  def handle_call(
        {:create_transaction, amount, receiver_pid, receiver_bitcoinaddr_pubkey},
        _from,
        state
      ) do
    # Create transaction
    Logger.debug("Working to create_tx and state: " <> inspect(state))
    # Convert to satoshis
    satoshi_multiplier = 100_000_000
    amount = (amount * satoshi_multiplier) |> trunc()

    # Pick up the utxos for the specified amount and call create_transaction_block with their list and btc address
    path = Path.absname("./lib/data/")
    # Logger.debug(inspect(__MODULE__) <> "Dir path: " <> inspect(path))
    node_id = inspect(state.owner_id)
    filename = node_id <> "utxo" <> ".json"
    :ok = File.mkdir_p!(path)

    {:ok, utxos_map} = SB.Tx.get_json(path <> "/" <> filename)
    Logger.debug("UTXOS map: " <> inspect(utxos_map))
    utxo_keys = Map.keys(utxos_map)
    Logger.debug("UTXO keys: " <> inspect(utxo_keys))

    utxos = [utxos_map]
    # create_utxos([], utxos_map, utxo_keys, 0, amount)
    Logger.debug("UTXOS: " <> inspect(utxos))

    tx_block =
      SB.Tx.create_transaction_block(
        node_id,
        utxos,
        receiver_bitcoinaddr_pubkey,
        amount,
        state.secret_key,
        state.public_key
      )

    Logger.debug("Created tx block: " <> inspect(tx_block))

    # Publish transaction
    publish_transaction(tx_block)

    {:reply, :ok, state}
  end

  def handle_call(
        {:create_coinbase_transaction, amount},
        _from,
        state
      ) do
    # Convert to satoshis
    satoshi_multiplier = 100_000_000
    amount = (amount * satoshi_multiplier) |> trunc()

    tx = SB.Tx.coinbase_transaction(amount, state.public_key)

    Logger.debug("Created coinbase tx block: " <> inspect(tx))

    publish_transaction(tx)
    {:reply, :ok, state}
  end

  defp publish_transaction(tx) do
    out = :ets.lookup(:ets_trans_repo, :new_tranx)
    Logger.debug("Publish tx called : #{inspect(out)} ")

    map =
      if(out == nil || out == []) do
        %{}
      else
        [{_, map}] = out
        map
      end

    # Logger.debug("Tx hash is an atom: " <> inspect(Map.put(map, tx.hash, tx)))
    :ets.insert(:ets_trans_repo, {:new_tranx, Map.put(map, tx.hash, tx)})

    SB.Node.get_miners()
    |> Enum.map(fn miner -> send(miner, {:new_transaction, tx}) end)
  end

  # TODO: Save and load wallet from files

  def update_wallet_with_block(wallet, block) do
    # TODO
    updated_wallet = wallet

    # Logger.debug("Inside #{inspect __MODULE__} Update wallet. Before updated blocks #{inspect updated_wallet.blocks}")
    Logger.debug("Update wallet. Before updated blocks #{inspect(block.tx)}")
    updated_blocks = updated_wallet.blocks ++ [block]

    # Logger.debug("Inside #{inspect __MODULE__} Update wallet. After updated blocks #{inspect updated_blocks}")
    # TODO Add block present in wallet blocks check
    updated_wallet = %{updated_wallet | blocks: updated_blocks}

    # TODO Update balance from transaction for blocks on this wallet
    updated_wallet = update_wallet_balance(updated_wallet, block)

    # Logger.debug("Inside #{inspect __MODULE__} Update wallet. #{inspect updated_wallet.blocks} with block - #{inspect block.block_id}")
    updated_wallet
  end

  def update_wallet_with_new_tx(wallet, new_tx) do
    # TODO: Update files after transaction validation from the miners

    Logger.debug("Update wallet with tx - #{inspect(new_tx)}")
    {num_inputs, _} = Integer.parse(new_tx.num_inputs)
    # Assuming last output is change output back to receiver
    sender_wallet_addr_hash = List.last(new_tx.outputs).scriptPubKey

    for x <- 1..num_inputs do
      input = Enum.fetch(new_tx.inputs, x - 1)
      wallet_pid = lookup_wallet_pid(sender_wallet_addr_hash)
      GenServer.call(wallet_pid, {:update_wallet_sender, new_tx})
    end

    {num_outputs, _} = Integer.parse(new_tx.num_outputs)
    Logger.debug("Number of Outputs: " <> inspect(num_outputs))

    for x <- 1..num_outputs do
      {:ok, output} = Enum.fetch(new_tx.outputs, x - 1)
      Logger.debug("Output: " <> inspect(output))
      wallet_pid = lookup_wallet_pid(output.scriptPubKey)
      GenServer.call(wallet_pid, {:update_wallet_receiver, new_tx})
    end
  end

  defp lookup_wallet_pid(script_pub_key) do
    wallet_pid =
      try do
        [{_, wallet_pid}] = :ets.lookup(:ets_wallet_addrs, script_pub_key)
        # Registry.lookup(SB.Registry.NodeInfo, %{node_id: state.node_id, val: :nonce})
        wallet_pid
      rescue
        e in [MatchError] ->
          nil
      end
  end

  defp update_wallet_balance(wallet, block) do
    # updated_wallet = wallet
    #    new_tx = Enum.fetch(block.tx, -1)
    #    balance = wallet.balance + new_tx.amount
    #    updated_wallet = %{updated_wallet | balance: balance}
    # updated_wallet
    wallet
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end
end
