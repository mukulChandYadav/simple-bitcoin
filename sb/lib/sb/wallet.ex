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

    {:ok, wallet_state}
  end

  def handle_call(:get_state_info, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call(:get_pub_key, _from, state) do
    {:reply, :ok, state.public_key}
  end

  def create_utxos(utxos, _, _, remaining_amount) when remaining_amount <= 0 do
    utxos
  end

  def create_utxos(utxos, utxos_map, utxo_keys, key_index, remaining_amount) do
    key = Enum.fetch(utxo_keys, key_index)
    utxo = Map.get(utxos_map, key)

    utxos = utxos ++ [utxo]
    utxo_amount = utxo[:value] |> String.to_integer(16)

    create_utxos(utxos, utxos_map, utxo_keys, key_index + 1, remaining_amount - utxo_amount)
  end

  def handle_call({:get_balance}, state) do
    balance = 0
    node_id = state.owner_id

    path = Path.absname("./lib/data/")
    Logger.debug(inspect(__MODULE__) <> "Dir path: " <> inspect(path))
    filename = node_id <> "utxo" <> ".json"

    utxos_map =
      (path <> "/" <> filename)
      |> SB.Tx.get_json()

    # utxo_keys = Map.keys(utxos_map)

    balance =
      Enum.reduce(utxos_map, 0, fn {_, utxo}, acc ->
        transaction_balance =
          Enum.reduce(utxo, 0, fn {_, out_index_map}, sum ->
            amount = out_index_map[:value] |> String.to_integer(16)
            sum + amount
          end)

        acc + transaction_balance
      end)

    Logger.debug("Balance: " <> inspect(balance))
    {:reply, :ok, balance}
  end

  def handle_call(
        {:create_transaction, amount, receiver_pid, receiver_bitcoinaddr_pubkey},
        _from,
        state
      ) do
    # Create transaction

    # Convert to satoshis
    satoshi_multiplier = 100_000_000
    amount = (amount * satoshi_multiplier) |> trunc()

    # Pick up the utxos for the specified amount and call create_transaction_block with their list and btc address
    path = Path.absname("./lib/data/")
    Logger.debug(inspect(__MODULE__) <> "Dir path: " <> inspect(path))
    filename = state.node_id <> "utxo" <> ".json"
    :ok = File.mkdir_p!(path)

    utxos_map = SB.Tx.get_json(path)
    utxo_keys = Map.keys(utxos_map)

    utxos = create_utxos([], utxos_map, utxo_keys, 0, amount)

    tx_block =
      SB.Tx.create_transaction_block(state.node_id, utxos, receiver_bitcoinaddr_pubkey, amount)

    # Publish transaction
    publish_transaction(tx_block)

    {:reply, :ok, state}
  end

  defp publish_transaction(tx) do
    out = :ets.lookup(:ets_trans_repo, :new_tranx)
    #### Logger.debug("#{inspect __MODULE__} Get Miners : #{inspect out} ")
    map =
      if(out == nil) do
        %{}
      else
        [{_, map}] = out
        map
      end

    :ets.insert(:ets_trans_repo, {:new_tranx, Map.put(map, tx.id, tx)})

    SB.Node.get_miners()
    |> Enum.map(fn miner -> GenEvent.notify(miner, {:new_transaction, tx}) end)
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  # TODO: Save and load wallet from files

  def update_wallet_with_block(wallet, block) do
    # TODO
    updated_wallet = wallet

    # Logger.debug("Inside #{inspect __MODULE__} Update wallet. Before updated blocks #{inspect updated_wallet.blocks}")
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
  end

  defp update_wallet_balance(wallet, block) do
    # updated_wallet = wallet
    #    new_tx = Enum.fetch(block.tx, -1)
    #    balance = wallet.balance + new_tx.amount
    #    updated_wallet = %{updated_wallet | balance: balance}
    # updated_wallet
    wallet
  end
end
