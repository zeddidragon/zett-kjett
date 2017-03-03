defmodule ZettKjett.Models.Server do
  @enforce_keys [:id]
  defstruct [
    id: nil,
    name: "<unnamed server>",
    owner: nil
  ]
end
