defmodule ZettKjett.Models.Chat do
  @enforce_keys [:id, :protocol]
  defstruct [
    id: nil,
    user_id: nil,
    protocol: :unknown_protocol
  ]
end
