defmodule ZettKjett.Protocols.Base do
  use ZettKjett.Cache
  alias ZettKjett.Models.{Chat, User, Message}

  def start_link do
    init_cache()
  end

  @callback me!() :: User
  def me do
    cached :me, &me/0
  end
  @callback nick!(String.t) :: User
  @callback friends!() : [Chat]
  def friends do
    cached :friends, &friends/0
  end

  @callback message!({id: String.t}, Message) : Message
end
