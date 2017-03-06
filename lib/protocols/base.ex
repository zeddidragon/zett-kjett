defmodule ZettKjett.Protocols.Base do
  alias ZettKjett.Models.{Channel, User, Message}
  @callback start_link(pid) :: any
  @callback me() :: User
  @callback nick(String.t) :: any
  @callback friends() :: [User]
  @callback chats() :: [{Channel, [User]}]
  @callback history(Channel) :: [{User, Message}]
  @callback tell(Channel, String) :: any
end
