defmodule ZettKjett.Models.Channel do
  @enforce_keys [:id]
  defstruct [
    id: nil,
    server_id: nil,
    name: "<unnamed channel>",
    private: false,
    sort_by: nil,
    topic: nil
  ]
end
