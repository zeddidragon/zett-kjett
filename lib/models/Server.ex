defmodule Server do
  @enforce_keys [:id, :name, :protocol]
  defstruct [
    id: nil,
    name: "<unnamed server>",
    protocol: :unknown_protocol,
    owner: nil
  ]
end
