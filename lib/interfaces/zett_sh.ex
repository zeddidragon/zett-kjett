defmodule ZettKjett.Interfaces.ZettSH do
  alias IO.ANSI
  alias ZettKjett.Utils
  alias ZettKjett.Interfaces.ZettSH.{Ctrl}

  def start_link do
    Task.start_link &input_loop/0
    Task.start_link &message_loop/0
  end
  
  defp system message do
    IO.puts "\r=== " <> message 
  end
  defp error message do
    IO.puts "\rERROR: " <> message
  end

  def message_loop do
    receive do
      {{:switch_protocol}, protocol} ->
        system "Protocol changed to " <> protocol_name(protocol)
      {{:join_chat, _, user}, _} ->
        system "Now talking with " <> user.name
      {{:message, _, user, message}, _} ->
        IO.puts "\r <#{user.name}> " <> message.content
      {{:nick, user}, _} ->
        system "Nick changed to " <> user.name
      {{:me, _}, _} ->
        :ok # Nothing
      {{:friends, _}, protocol} ->
        system "Friend list received from " <> protocol_name(protocol)
      message ->
        message |> inspect |> system
    end
    message_loop()
  end

  def input_loop do
    me = ZettKjett.me
    prompt = me && me.name || ""
    IO.gets(prompt <> "> ")
      |> String.trim
      |> parse_input
    input_loop()
  end

  def parse_input input do
    if "/" == String.first input do
      [cmd | args] = input
        |> String.slice(1..-1)
        |> String.split
      run_command String.downcase(cmd), args
    else
      tell input
    end
  end

  defp find_friend target do
    ZettKjett.friends
      |> compare_friends(target)
      |> hd()
  end

  defp compare_friends friends, string do
    string = String.downcase string
    Enum.sort_by friends, fn {user, _} ->
      user.name
        |> String.downcase
        |> String.jaro_distance(string)
        |> Kernel.-
    end
  end

  defp protocol_name protocol do
    to_string protocol
  end

  defp compare_protocols protocols, string do
    string = String.downcase string
    Enum.sort_by protocols, fn protocol ->
      protocol
        |> protocol_name()
        |> String.downcase
        |> String.jaro_distance(string)
        |> Kernel.-
    end
  end

  defp tell_friend friend, string do
    ZettKjett.tell friend, string
  end
  
  defp run_command "protocols", _ do
    protocols()
  end

  defp run_command "switch", [target | _] do
    switch target
  end
  defp run_command "switch", _ do
    error "Usage: \"/switch <protocol>\""
  end

  defp run_command "friends", _ do
    redraw()
  end

  defp run_command "tell", [target | args] do
    tell target, Enum.join(args, " ")
  end
  defp run_command "tell", _ do
    error "Usage: \"/tell <friend> [<message>]\""
  end

  defp run_command "history", [target | _] do
    (friend = find_friend target)
      && print_history(ZettKjett.history(friend))
  end
  defp run_command "history", _ do
    print_history ZettKjett.history
  end

  defp run_command "nick", [] do
    error "Usage: \"/nick <new name>\""
  end
  defp run_command "nick", args do
    nick Enum.join(args, " ")
  end

  defp run_command unknown, _ do
    error "Unknown function: /" <> unknown
  end

  def protocols do
    system "PROTOCOLS"
    for protocol <- ZettKjett.protocols do
      system " " <> protocol_name(protocol)
    end
  end

  def switch target do
    ZettKjett.protocols
      |> compare_protocols(target)
      |> hd()
      |> ZettKjett.switch()
  end

  @friends_list_width 32
  defp zett_tree_item str do
    String.pad_trailing(str, @friends_list_width) <>
    ANSI.color(3, 3, 3) <>
    ANSI.color_background(1, 1, 1) <>
    "|\n" <>
    ANSI.default_color <>
    ANSI.default_background
  end

  defp zett_tree_item entry, :protocol do
    zett_tree_item(ANSI.color(5, 1, 1) <> "<#{entry}>/")
  end

  defp zett_tree_item {user, _}, :friend do
    zett_tree_item(ANSI.color(4, 4, 4) <> "  @#{user.name}")
  end

  defp zett_tree_item entry, type do
    Utils.inspect type
    Utils.inspect entry
  end

  def zett_tree do
    str = ZettKjett.protocols
      |> Enum.map(fn protocol ->
        zett_tree_item(protocol, :protocol) <>
        friends(protocol)
      end)
      |> Enum.join("")
    str <> ANSI.default_color() <> ANSI.default_background()
  end

  def draw_tree do
    list = Enum.join([
      Ctrl.save_cursor,
      Ctrl.home,
      zett_tree(),
      Ctrl.load_cursor
    ], "")
    IO.write list
  end

  def redraw do
    draw_tree()
  end

  def friends protocol do
    ZettKjett.friends(protocol)
      |> Enum.map(&zett_tree_item(&1, :friend))
      |> Enum.join("")
  end

  def nick name do
    case ZettKjett.nick name do
      {:error, message} -> message |> to_string |> error
      _ -> {:ok}
    end
  end

  defp tell message do
    ZettKjett.tell message
  end

  def tell target, message do
    (friend = find_friend(target))
      && tell_friend(friend, message)
  end

  defp print_history messages do
    for {user, message} <- Enum.reverse messages do
      IO.puts "<#{user.name}> #{message.content}"
    end
  end
end

defmodule ZettKjett.Interfaces.ZettSH.Ctrl do
  def move row, col do
    "\e[#{row};#{col}H"
  end
  def home, do: move(0,0)
  def save_cursor, do: "\e[s"
  def load_cursor, do: "\e[u"
end
