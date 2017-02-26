defmodule User do
  @enforce_keys [:id, :name]
  defstruct [
    id: nil,
    name: "<unnamed schmuck>",
    color: nil
  ]
end
