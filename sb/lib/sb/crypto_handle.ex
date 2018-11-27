defmodule SB.CryptoHandle do
  @n :binary.decode_unsigned(<<
       0xFF,
       0xFF,
       0xFF,
       0xFF,
       0xFF,
       0xFF,
       0xFF,
       0xFF,
       0xFF,
       0xFF,
       0xFF,
       0xFF,
       0xFF,
       0xFF,
       0xFF,
       0xFE,
       0xBA,
       0xAE,
       0xDC,
       0xE6,
       0xAF,
       0x48,
       0xA0,
       0x3B,
       0xBF,
       0xD2,
       0x5E,
       0x8C,
       0xD0,
       0x36,
       0x41,
       0x41
     >>)

  @alphabet '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'

  defp validate_key?(key) when key > 1 and key < @n do
    true
  end

  defp validate_key?(_) do
    false
  end

  def generate_private_key do
    private_key = :crypto.strong_rand_bytes(32)

    key_unsigned_int =
      private_key
      |> :binary.decode_unsigned()

    case validate_key?(key_unsigned_int) do
      true ->
        private_key

      false ->
        generate_private_key()
    end
  end

  def generate_public_key(private_key) do
    :crypto.generate_key(:ecdh, :crypto.ec_curve(:secp256k1), private_key)
    |> elem(0)
  end

  def hash(data, type) do
    :crypto.hash(type, data)
  end

  def encoded_hash(data, type) do
    hash(data, type)
    |> Base.encode16()
    |> String.downcase()
  end

  def generate_public_hash(private_key) do
    private_key
    |> generate_public_key
    |> hash(:sha256)
    |> hash(:ripemd160)
  end

  defp leading_zeros(data) do
    :binary.bin_to_list(data)
    |> Enum.find_index(&(&1 != 0))
  end

  defp encode_zeros(data) do
    <<Enum.at(@alphabet, 0)>>
    |> String.duplicate(leading_zeros(data))
  end

  def encode(data, hash \\ "")

  def encode(data, hash) when is_binary(data) do
    encode_zeros(data) <> encode(:binary.decode_unsigned(data), hash)
  end

  def encode(0, hash), do: hash

  def encode(data, hash) do
    character = <<Enum.at(@alphabet, rem(data, 58))>>
    encode(div(data, 58), character <> hash)
  end

  defp split(<<hash::bytes-size(4), _::bits>>), do: hash

  defp checksum(version, data) do
    (version <> data)
    |> hash(:sha256)
    |> hash(:sha256)
    |> split
  end

  def encode_prefix_hash_checksum(data, version) do
    version <> data <> checksum(version, data)
  end

  def generate_address(private_key, version \\ <<0x00>>) do
    private_key
    |> generate_public_hash
    |> encode_prefix_hash_checksum(version)

    # |> encode
  end

  def main do
    # encode(<<0x00>> <> <<0x00>> <> "hello")
    # |> IO.inspect()

    generate_private_key()
    |> generate_address
    |> IO.inspect()
  end
end

IO.inspect(SB.CryptoHandle.main())
