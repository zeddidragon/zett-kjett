defmodule ZettKjett.Cache do
  @moduledoc """
  Provides a simple interface for caching values. Example:

  ## Examples
  ```elixir
  def MyModule do
    using ZettKjett.Cache

    def start_link
      init_cache
    end

    def value! do
      make_a_http_request_or_something
    end

    def value do
      cached :value, &value!/0
    end
  end
  ```
  """
  defmacro __using__(opts) do
    quote do
      @namespace unquote(opts[:namespace] || false) || :"zCache:#{__MODULE__}"
      def init_cache do
        Agent.start_link fn -> %{} end, name: @namespace
      end

      def cached key, getter do
        Agent.update @namespace, &Map.put_new_lazy(&1, key, getter)
        Agent.get @namespace, &Map.get(&1, key)
      end

      def cache key, value do
        Agent.update @namespace, &Map.put(&1, key, value)
      end
    end
  end
end

