defmodule ZettKjett.Protocols.Servers do
  alias ZettKjett.Models.{Server, Channel, User, Message}
  @callback servers() :: [Server]
  @callback leave_server(Server) :: any
  @callback delete_server(Server) :: any
  @callback channels(Server) :: [Channel]
end
