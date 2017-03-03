defmodule ZettKjett.Models.User do
  @enforce_keys [:id]
  defstruct [
    id: nil,
    name: "<unnamed schmuck>",
    color: nil
  ]
end
