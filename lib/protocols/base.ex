defmodule ZettKjett.Protocols.Base do
  alias ZettKjett.Models.{Chat, User, Message}
  @callback start_link(pid) :: any
  @callback me() :: User
  @callback nick(String.t) :: any
  @callback friends() :: [{Chat, User}]
  @callback history(Chat) :: [Message]
  @callback tell(Chat, String) :: any
end
