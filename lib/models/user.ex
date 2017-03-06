defmodule ZettKjett.Models.User do
  @enforce_keys [:id, :name]
  defstruct [
    id: nil,
    name: nil,
    color: nil,
    status: nil
  ]
end
