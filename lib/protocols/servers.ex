defmodule ZettKjett.Protocols.Servers do
  use ZettKjett.Protocols.Base
  alias ZettKjett.Models.{Server, Channel, User, Message}

  def start_link do
    init_cache()
  end

  @callback me!() :: User
  def me do
    cached :me, &me/0
  end
  @callback nick!(String.t) :: User

  @callback servers!() : [Server]
  def servers do
    cached :servers, &server/0
  end
  @callback leave_server!(Server) :: Server
  @callback delete_server!(Server) :: Server

  @callback channels!(Server) : [Channel]
  def channels server do
    cached :"/channels:#{server.id}", &channels!(server)
  end

  @callback friends!() : [Chat]
end
