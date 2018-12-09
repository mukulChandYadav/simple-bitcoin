defmodule SB.Wallet do
  @moduledoc false

  use GenServer

  require Logger
  #TODO: Add cryptographic functionalities

  def start_link(state, opts) do
    #####Logger.debug("Inside #{inspect __MODULE__} Node start_link of #{inspect self}")
    GenServer.start_link(__MODULE__, state, opts)
  end

  def start_link(opts) do
    #####Logger.debug("Inside #{inspect __MODULE__} Node start_link with opts - #{inspect opts}")
    ret_val = GenServer.start_link(__MODULE__, opts)
    #####Logger.debug("Inside #{inspect __MODULE__} ret val - #{inspect ret_val}")
    ret_val
  end

  def init(opts) do
    Logger.debug("Called with  - #{inspect opts}")

    wallet_state = %SB.WalletInfo{secret_key: opts.secret_key, public_key: opts.public_key, owner_pid: opts.owner_pid, wallet_pid: self()}

    #TODO Initialize wallet state from static file

    {:ok, wallet_state}
  end


  def handle_call(:get_state_info, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call(:get_pub_key, _from, state) do
    {:reply, :ok, state.public_key}
  end

  def handle_call({:create_transaction, tx}, _from, state) do

    # Create transaction

    # Publish transaction
    publish_transaction(tx)

    {:reply, :ok, state}
  end

  defp publish_transaction(tx) do

    out = :ets.lookup(:ets_trans_repo, :new_tranx)
    ####Logger.debug("#{inspect __MODULE__} Get Miners : #{inspect out} ")
    map = if(out == nil) do
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

  #TODO: Save and load wallet from files

  def update_wallet_with_block(wallet, block) do
    #TODO
    updated_wallet = wallet
    #Logger.debug("Inside #{inspect __MODULE__} Update wallet. Before updated blocks #{inspect updated_wallet.blocks}")
    updated_blocks = (updated_wallet.blocks ++ [block])
    #Logger.debug("Inside #{inspect __MODULE__} Update wallet. After updated blocks #{inspect updated_blocks}")
    #TODO Add block present in wallet blocks check
    updated_wallet = %{updated_wallet | blocks: updated_blocks}

    #TODO Update balance from transaction for blocks on this wallet
    updated_wallet = update_wallet_balance(updated_wallet, block)
    #Logger.debug("Inside #{inspect __MODULE__} Update wallet. #{inspect updated_wallet.blocks} with block - #{inspect block.block_id}")
    updated_wallet
  end

  defp update_wallet_balance(wallet, block) do
    #updated_wallet = wallet
    #    new_tx = Enum.fetch(block.tx, -1)
    #    balance = wallet.balance + new_tx.amount
    #    updated_wallet = %{updated_wallet | balance: balance}
    #updated_wallet
    wallet
  end

end
