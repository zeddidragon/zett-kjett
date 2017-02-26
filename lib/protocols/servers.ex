defmodule ZettKjett.Protocols.Servers do
  alias ZettKjett.Models.{Server, Channel, User, Message}
  @callback servers!() :: [Server]
  @callback leave_server!(Server) :: any
  @callback delete_server!(Server) :: any
  @callback channels!(Server) :: [Channel]

  defmacro __using__(_) do
    quote do
      use ZettKjett.Protocols.Base

      def me do
        cached :me, &me/0
      end

      def servers do
        cached :servers, &server/0
      end
      def channels server do
        cached :"/channels:#{server.id}", &channels!(server)
      end
    end
  end
end
