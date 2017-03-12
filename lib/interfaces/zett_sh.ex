defmodule ZettKjett.Interfaces.ZettSH.State do
  defstruct [
    rows: 1,
    cols: 1,
    expanded: %{},
    system_messages: []
  ]
end

defmodule ZettKjett.Interfaces.ZettSH do
  alias IO.ANSI
  alias ZettKjett.Utils
  alias ZettKjett.Interfaces.ZettSH.{Ctrl, State}
  alias ZettKjett.Models.{Message}
  @friends_list_width 24
  @chat_x @friends_list_width + 1

  IO.write ANSI.clear
  def start_link do
    state = %State{}
    Task.start_link fn ->
      input_loop()
    end
    Task.start_link fn ->
      state = redraw state
      IO.write Ctrl.move(state.rows, 0)
      message_loop state
    end
  end

  defp system message do
    time = Timex.now
    msg = %Message{
      id:  "system|#{time}",
      sent_at: time,
      content: message,
      user_id: nil,
      channel_id: nil
    }
    send ZettKjett.Interface, {:system_message, msg}
  end
  defp error message do
    time = Timex.now
    msg = %Message{
      id:  "error|#{time}",
      sent_at: time,
      content: message,
      user_id: nil,
      channel_id: nil
    }
    send ZettKjett.Interface, {:system_message, msg}
  end

  def message_loop state do
    state = receive do
      {:system_message, msg} ->
        redraw %{
          state |
          system_messages: [{nil, msg} | state.system_messages]
        }
      {{:switch_protocol}, protocol} ->
        system "Protocol changed to " <> protocol_name(protocol)
        state
      {{:join_chat, _, user}, _} ->
        state
      {{:message, _, user, message}, _} ->
        redraw state
      {{:nick, user}, _} ->
        system "Nick changed to " <> user.name
        state
      {{:me, _}, _} ->
        state
      {{:friends, _}, protocol} ->
        redraw state
      message ->
        message |> inspect |> system
        state
    end
    message_loop state
  end

  def input_loop do
    me = ZettKjett.me
    prompt = me && me.name || ""
    IO.gets("")
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
  
  defp run_command "tell", [target | args] do
    tell target, Enum.join(args, " ")
  end
  defp run_command "tell", _ do
    error "Usage: \"/tell <friend> [<message>]\""
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

  defp zett_tree_item {entry, :protocol} do
    zett_tree_item(ANSI.color(5, 1, 1), "<#{entry}>/")
  end

  defp zett_tree_item {{user, _}, :friend} do
    zett_tree_item(ANSI.color(4, 4, 4), "  #{user.name}")
  end

  defp zett_tree_item nil do
    zett_tree_item(ANSI.color(1, 1, 1), "~")
  end

  defp zett_tree_item {entry, type} do
    Utils.inspect type
    Utils.inspect entry
    zett_tree_item ANSI.color(5, 0, 0), "==UNKNOWN=="
  end

  defp zett_tree_item color, str do
    color <>
    String.pad_trailing(str, @friends_list_width) <>
    ANSI.color(3, 3, 3) <>
    ANSI.color_background(1, 1, 1) <>
    "|\n" <>
    ANSI.default_color <>
    ANSI.default_background
  end

  def zett_tree_list do
    Enum.flat_map ZettKjett.protocols, fn protocol ->
      [{protocol, :protocol} | friends(protocol)]
    end
  end
  
  def zett_tree_height state do
    state.rows - 2  # Leave space for input line
  end

  def zett_tree state do
    intended_height = zett_tree_height state
    str  = zett_tree_list()
      |> Utils.pad_trailing(intended_height)
      |> Enum.slice(0..intended_height)
      |> Enum.map(&zett_tree_item/1)
      |> Enum.join("")
    str <> ANSI.default_color() <> ANSI.default_background()
  end

  def draw_tree state do
    list = Enum.join([
      Ctrl.save_cursor,
      Ctrl.home,
      zett_tree(state),
      Ctrl.load_cursor
    ], "")
    IO.write list
    state
  end

  def draw_statusbar state do
    me = ZettKjett.me
    status =
      if me do
        "<#{ZettKjett.protocol}>/ #{me.name}"
      else
        "<no protocol selected>"
      end
    str =
      Ctrl.save_cursor() <>
      Ctrl.move(state.rows - 1, 0) <>
      ANSI.color(0, 0, 0) <>
      ANSI.color_background(1, 1, 1) <>
      String.pad_trailing(status, state.cols) <>
      ANSI.default_color <>
      ANSI.default_background <>
      Ctrl.load_cursor
    IO.write str
    state
  end

  def history_height state do
    state.rows - 2  # Leave room for command line and status
  end

  def history_width state do
    width = state.cols - @chat_x
  end

  def history_time stamp do
    Timex.format! stamp, "{YYYY} {Mshort} {_D} {0h24}:{0m}"
  end

  defp cut_string string, width do
    if String.length(string) < width do
      [string]
    else
      [String.slice(string, 0..(width - 1)) |
       cut_string(String.slice(string, width..-1), width)]
    end
  end

  def history_item {user, msg}, state do
    stamp = history_time msg.sent_at
    width = history_width(state) - 1
    header_width = width - String.length(stamp)

    header =
      if user do
        ANSI.underline <>
        ANSI.color(2, 2, 2) <>
        String.pad_trailing(" " <> user.name, header_width) <>
        stamp <>
        ANSI.reset
      else
        ANSI.underline <>
        ANSI.color(3, 1, 1) <>
        String.pad_trailing(" SYSTEM", header_width) <>
        stamp <>
        ANSI.reset
      end
    content = msg.content
      |> String.split
      |> Enum.flat_map(&cut_string(&1, width))
      |> Enum.reduce([""], fn word, [line | lines] ->
        if String.length(line) + String.length(word) < width do
          [line <> " " <> word | lines]
        else
          [" " <> word | [line | lines]]
        end
      end)
      |> Enum.reverse
      |> Enum.map(&String.pad_trailing(&1, width))
    [header | content]
  end

  defp timestamp {_, msg} do
    msg.sent_at |> Timex.to_unix
  end

  def draw_history state do
    width = history_width(state)
    height = history_height(state)
    history = ZettKjett.history
      |> Enum.concat(state.system_messages)
      |> Enum.sort_by(&timestamp/1)
      |> Enum.flat_map(&history_item(&1, state))
      |> Utils.pad_leading(height, String.duplicate(" ", width))
      |> Enum.join("\n" <> Ctrl.right(@chat_x))
    str =
      Ctrl.save_cursor() <>
      Ctrl.move(0, @chat_x + 1) <>
      history <>
      Ctrl.load_cursor()
    IO.write str
    state
  end

  def redraw state do
    {rows, 0} = System.cmd "tput", ["lines"]
    {cols, 0} = System.cmd "tput", ["cols"]
    state = %{
      state |
      rows: Utils.parse_int(rows),
      cols: Utils.parse_int(cols)
    }
    IO.write ANSI.clear
    draw_tree state
    draw_statusbar state
    draw_history state
    state
  end

  def friends protocol do
    ZettKjett.friends(protocol)
      |> Enum.map(fn friend -> {friend, :friend} end)
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
end

defmodule ZettKjett.Interfaces.ZettSH.Ctrl do
  def save_cursor, do: "\e[s"
  def load_cursor, do: "\e[u"
  def move row, col do
    "\e[#{row};#{col}H"
  end
  def home, do: move(0,0)
  def up n do
    "\e[#{n}A"
  end
  def down n do
    "\e[#{n}B"
  end
  def right n do
    "\e[#{n}C"
  end
  def left n do
    "\e[#{n}D"
  end
end
