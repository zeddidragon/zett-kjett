defmodule ZettKjett.Protocols.Base do
  alias ZettKjett.Models.{Chat, User, Message}
  @callback start_link!(pid) :: any
  @callback me!() :: User
  @callback nick!(String.t) :: any
  @callback friends!() :: [{Chat, User}]
  @callback message!(Chat, String) :: any

  defmacro __using__(_) do
    quote do
      use ZettKjett.Cache

      def start_link listener do
        init_cache()
        start_link! listener
      end

      def me do
        cached :me, &me!/0
      end

      def friends do
        cached :friends, &friends!/0
      end
    end
  end
end
