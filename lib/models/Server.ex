defmodule ZettKjett.Models.Server do
  @enforce_keys [:id, :protocol]
  defstruct [
    id: nil,
    name: "<unnamed server>",
    protocol: :unknown_protocol,
    owner: nil
  ]
end
