defmodule SB.Tx do
  require Logger

  def get_pid do
    self()
    |> :erlang.pid_to_list()
    |> to_string
    |> String.slice(1..-2)
  end

  def get_json(filename) do
    with {:ok, body} <- File.read(filename), {:ok, json} <- Poison.decode(body), do: {:ok, json}
  end

  def append_json(type, path, content) when type == "utxo" do
    tx_id = content[:hash]
    output_index = content[:out_index]

    content = Map.drop(content, [:hash, :out_index])

    {:ok, json} =
      path
      |> get_json

    Logger.debug("content: " <> inspect(content))

    case Map.has_key?(json, tx_id) do
      true ->
        {_, appended_submap} =
          Map.get_and_update!(json, tx_id, fn curr_map ->
            {curr_map, Map.put(curr_map, output_index, content)}
          end)

        appended_submap

      false ->
        out_index_map = Map.put(%{}, output_index, content)
        Map.put(json, tx_id, out_index_map)
    end
  end

  def append_json(_, path, content) do
    tx_id = content[:hash]

    {:ok, json} =
      path
      |> get_json

    Map.put(json, tx_id, content)
  end

  def write_json(type, content) when content == %{} do
    Logger.debug("---------Content empty--------")
    Logger.debug("Type: " <> inspect(type))

    path = "./lib/data/" <> get_pid() <> type <> ".json"

    json_encoded_content =
      %{}
      |> Poison.encode!()

    File.write!(path, json_encoded_content)
  end

  def write_json(type, content) do
    path = "./lib/data/" <> get_pid() <> type <> ".json"

    Logger.debug("---------Content not empty--------")
    Logger.debug("Content: " <> inspect(content))
    Logger.debug("Type: " <> inspect(type))

    json_encoded_content =
      append_json(type, path, content)
      |> Poison.encode!()

    File.write!(path, json_encoded_content)
  end

  defp get_pub_key_hash(bc_addr) do
    String.slice(bc_addr, 2..-9)
  end

  # defp generate_map_string(list) do
  #   Enum.reduce(list, "", fn input, acc ->
  #     values = Map.values(input)

  #     map_values_string =
  #       Enum.reduce(values, "", fn value, accum ->
  #         accum <> value
  #       end)

  #     acc <> map_values_string
  #   end)
  # end

  # def create_transaction_block(utxos, _, _) when utxos == [] do
  #   false
  # end

  # def create_transaction_block(utxos, bc_addr, amount) do
  #   # Creating outputs
  #   # outputs = [
  #   #   {
  #   #     value
  #   #     script_len
  #   #     scriptPubKey
  #   #   }
  #   # ]

  #   outputs = []

  #   pub_key_hash =
  #     bc_addr
  #     |> get_pub_key_hash

  #   scriptPubKey = "76a914" <> pub_key_hash <> "88ac"

  #   script_len =
  #     scriptPubKey
  #         |> Binary.from_hex()
  #         |> byte_size()
  #         |> to_string()

  #   outputs = [outputs | %{value: amount, script_len: script_len, scriptPubKey: scriptPubKey}]

  #   # Creating inputs
  #   # inputs = [
  #   #   {
  #   #     prev_hash
  #   #     prev_out_index
  #   #     script_len
  #   #     scriptSig
  #   #     sequence
  #   #   }
  #   # ]

  #   inputs = []
  #   script_len = 0

  #   inputs =
  #     Enum.map(utxos, fn utxo ->
  #       script_len =
  #         utxo[:scriptPubKey]
  #         |> Binary.from_hex()
  #         |> byte_size()
  #         |> to_string()

  #       %{
  #         prev_hash: utxo[:tx_id],
  #         prev_out_index: utxo[:out_index],
  #         script_len: script_len,
  #         scriptSig: utxo[:pubKeyScript],
  #         sequence: "ffffffff"
  #       }
  #     end)

  #   locktime = "00000000"
  #   sigHash = "01000000"
  #   version = "01000000"

  #   num_inputs =
  #     length(utxos)
  #     |> Integer.to_string(16)
  #   num_inputs = "0" <> num_inputs

  #   num_outputs =
  #     length(outputs)
  #     |> Integer.to_string(16)
  #   num_outputs = "0" <> num_outputs

  #   # Evaluating ScriptSig for each input
  #   output_string = generate_map_string(outputs)

  #   Enum.map(inputs, fn input ->
  #     tx =
  #       (version <>
  #          num_inputs <>
  #          generate_map_string([input]) <> num_outputs <> output_string <> locktime <> sigHash)

  #       |> Integer.parse(16)
  #       |> elem(0)
  #       |> :binary.encode_unsigned()

  #     tx_hash =
  #       tx
  #       |> CryptoHandle.hash(:sha256)
  #       |> CryptoHandle.hash(:sha256)
  #   end)
  # end

  def coinbase_transaction do
    # version 1, uint32_t
    version = "01000000"

    # 1 input transaction, var_int
    tx_in_count = "01"

    # the default for generation transactions since there is no transaction to use as output
    outpoint_hash = "0000000000000000000000000000000000000000000000000000000000000000"

    # also default for generation transactions, uint32_t
    outPoint_index = "ffffffff"

    previous_output = outpoint_hash <> outPoint_index

    # 77, var_int
    script_length = "4d"

    # The coinbase. In a regular transaction this would be the scriptSig, but unused in generation transactions.
    # Satoshi inserted the headline of The Times to prove that mining did not start before Jan 3, 2009.
    # ???????EThe Times 03/Jan/2009 Chancellor on brink of second bailout for banks
    signature_script =
      "04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73"

    # final sequence, means it can't be replaced and is immediately locked, uint32_t
    sequence = "ffffffff"

    tx_in = previous_output <> script_length <> signature_script <> sequence

    # 1 transaction output, var_int
    tx_out_count = "01"

    # 5000000000 satoshis == 50 bitcoin, uint64_t
    value = "00f2052a01000000"

    # The scriptPubKey saying where the coins are going.
    pub_key_hash =
      CryptoHandle.generate_private_key()
      |> CryptoHandle.generate_address()
      |> Base.encode16()
      |> get_pub_key_hash

    Logger.debug("pk_hash: " <> inspect(pub_key_hash))

    pk_script = "76a914" <> pub_key_hash <> "88ac"
    Logger.debug("pk_script_: " <> inspect(pk_script))

    # "4104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac"

    pk_script_length =
      pk_script
      |> Binary.from_hex()
      |> byte_size()
      |> to_string()

    # |> Integer.parse(16)
    # |> elem(0)

    # |> byte_size

    Logger.debug("pk_script_length: " <> inspect(pk_script_length))

    # We can decode this.
    # 41 push the next 65 bytes onto the stack
    # 04678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5f the 65 bytes that get pushed onto the stack
    # ac OP_CHECKSIG
    # This is a pay-to-pubkey output, which is the default for generation transactions.

    tx_out = value <> pk_script_length <> pk_script

    # immediately locked, uint32_t
    lock_time = "00000000"

    # (version <> tx_in_count <> tx_in <> tx_out_count <> tx_out <> lock_time)
    transaction =
      (version <> tx_in_count <> tx_in <> tx_out_count <> tx_out <> lock_time)
      |> Binary.from_hex()

    Logger.debug("Transaction: " <> inspect(transaction))
    # Logger.debug("Transaction: " <> inspect(transaction |> Base.encode16()))

    trans_hash =
      transaction
      |> CryptoHandle.hash(:sha256)
      |> CryptoHandle.hash(:sha256)
      |> Base.encode16()

    # Tx content
    # hash: nil, version: "01000000", num_inputs: 0, inputs: [], num_outputs: 0, outputs: []

    %{
      hash: trans_hash,
      version: version,
      num_inputs: tx_in_count,
      inputs: [],
      num_outputs: tx_out_count,
      outputs: [
        %{
          value: value,
          script_len: pk_script_length,
          scriptPubKey: pk_script
        }
      ]
    }
  end

  def main do
    write_json("tx", %{})
    write_json("utxo", %{})

    content = coinbase_transaction()
    Logger.debug("Content: " <> inspect(content))

    write_json("tx", content)

    # Testing utxo
    op = Enum.at(content[:outputs], 0)

    utxo_content =
      Map.put(%{}, :hash, content[:hash])
      |> Map.put(:out_index, 0)
      |> Map.put(:value, op[:value])
      |> Map.put(:scriptPubKey, op[:scriptPubKey])

    write_json("utxo", utxo_content)
  end
end

SB.Tx.main()
|> IO.inspect()

IO.inspect("Main executed")
