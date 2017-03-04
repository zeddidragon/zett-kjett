defmodule ZettKjett.Models.Server do
  @enforce_keys [:id, :name]
  defstruct [
    id: nil,
    name: nil,
    owner: nil
  ]
end
