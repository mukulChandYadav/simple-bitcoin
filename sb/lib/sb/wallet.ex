defmodule SB.Wallet do
  @moduledoc false


  require Logger
  #TODO: use Agent
  #TODO: Add cryptographic functionalities


  #TODO: Save and load wallet from files

  defstruct balance: 0, blocks: []

  def update_wallet_with_block(wallet, block) do
    #TODO
    updated_wallet = wallet
    Logger.debug("Inside #{inspect __MODULE__} Update wallet. Before updated blocks #{inspect updated_wallet.blocks}")
    updated_blocks = (updated_wallet.blocks ++ [block])
    Logger.debug("Inside #{inspect __MODULE__} Update wallet. After updated blocks #{inspect updated_blocks}")
    #TODO Add block present in wallet blocks check
    updated_wallet = %{updated_wallet | blocks: updated_blocks}

    #TODO Update balance from transaction for blocks on this wallet
    updated_wallet = update_wallet_balance(updated_wallet, block)
    Logger.debug("Inside #{inspect __MODULE__} Update wallet. #{inspect updated_wallet.blocks} with block - #{inspect block.block_id}")
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
