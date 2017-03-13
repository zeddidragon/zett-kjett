defmodule ZettKjett.Interfaces.ZettSH.State do
  defstruct [
    rows: 1,  # terminal height
    cols: 1,  # terminal width
    expanded: %{},  # which items in the tree are expanded
    system_messages: [],  # messages from ZettSH to show in chat history
    typing: "",  # currently typed message
    typing_pos: 0,  # cursor location in command line
    mode: :normal,  # overall mode
    command: nil,  # currently prepared normal-mode command
    command_count: "",  # repeats for normal-mode commands
  ]
end

defmodule ZettKjett.Interfaces.ZettSH do
  alias IO.ANSI
  alias ZettKjett.Utils
  alias ZettKjett.Interfaces.ZettSH.{Ctrl, State}
  alias ZettKjett.Models.{Message}
  alias ZettKjett.Config
  @friends_list_width 24
  @chat_x @friends_list_width + 1

  @modes ["insert", "normal", "visual"]
  def start_link do
    config = (Config.get[:Interfaces] || %{})[:ZettSH] || %{}
    mode = config[:mode]
    mode =
      cond do
        Enum.member? @modes, mode ->
          String.to_atom mode
        !mode ->
          :normal
        true ->
          valid = Enum.join @modes, ", "
          raise ~s(Invalid mode "#{mode}". Valid modes are: [#{valid}])
      end
    state = %State{mode: mode}

    Task.start_link fn ->
      Port.open({:spawn, "tty_sl -c -e"}, [:binary, :eof])
      IO.write ANSI.clear
      state = redraw state
      IO.write Ctrl.move(state.rows, 0)
      message_loop state
    end
  end

  defp system message do
    time = Utils.now
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
    time = Utils.now
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
      {_, {:data, char}}->
        handle_input state.mode, char, state
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

  def parse_input input do
    if ":" == String.first input do
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
    error ~s(Usage: ":tell <friend> [<message>]")
  end

  defp run_command "nick", [] do
    error ~s("Usage: ":nick <new name>")
  end
  defp run_command "nick", args do
    nick Enum.join(args, " ")
  end

  defp run_command unknown, _ do
    error "Unknown function: :" <> unknown
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
    "|\n\r" <>
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
    status = "#{state.mode}|#{status}"
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

  defp cut_string string, width do
    if String.length(string) < width do
      [string]
    else
      [String.slice(string, 0..(width - 1)) |
       cut_string(String.slice(string, width..-1), width)]
    end
  end

  def history_header {user, msg}, state do
    stamp = Utils.format_timestamp msg.sent_at
    width = history_width(state) - String.length(stamp)
    if user do
      ANSI.underline <>
      ANSI.color(2, 2, 2) <>
      String.pad_trailing(" " <> user.name, width) <>
      stamp <>
      ANSI.reset
    else
      ANSI.underline <>
      ANSI.color(3, 1, 1) <>
      String.pad_trailing(" SYSTEM", width) <>
      stamp <>
      ANSI.reset
    end
  end

  def history_content {_, msg}, state do
    width = history_width(state) - 1
    msg.content
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
  end

  def history_item [nil, {user, msg}], state do
    [ history_header({user, msg}, state),
      history_content({user, msg}, state)
    ]
  end

  @same_time 300  # 5 minutes
  def history_item [{prev_user, prev_msg}, {user, msg}], state do
    same_user = prev_user == user
    same_time = Utils.time_diff(prev_msg.sent_at, msg.sent_at) < @same_time
    content = history_content({user, msg}, state)
    if same_user && same_time do
      content
    else
      [history_header({user, msg}, state) | content]
    end
  end

  defp timestamp {_, msg} do
    msg.sent_at
  end

  def draw_history state do
    width = history_width(state)
    height = history_height(state)
    history = ZettKjett.history
      |> Enum.concat(state.system_messages)
      |> Enum.sort_by(&timestamp/1)
      |> List.insert_at(0, nil)
      |> Enum.chunk(2, 1)
      |> Enum.flat_map(&history_item(&1, state))
      |> Enum.take(-height)
      |> Utils.pad_leading(height, String.duplicate(" ", width))
      |> Enum.join("\n\r" <> Ctrl.right(@chat_x))
    str =
      Ctrl.save_cursor() <>
      Ctrl.move(0, @chat_x + 1) <>
      history <>
      Ctrl.load_cursor()
    IO.write str
    state
  end

  def draw_commandline state do
    str =
      Ctrl.move(state.rows, 0) <>
      ANSI.clear_line <>
      state.typing <>
      Ctrl.move(state.rows, state.typing_pos + 1)
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
    state
      |> draw_history()
      |> draw_tree()
      |> draw_statusbar()
      |> draw_commandline()
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

  def typing_split state do
    String.split_at state.typing, state.typing_pos
  end

  defp set_mode state, mode do
    offset = if state.mode == :insert do -1 else 0 end
    %{state | mode: mode}
      |> set_typing_pos(state.typing_pos + offset)
      |> reset_command()
      |> draw_statusbar()
      |> draw_commandline()
  end

  defp set_typing state, str do
    %{state | typing: str, typing_pos: String.length(str)}
  end

  defp set_typing_pos state, pos do
    new_pos = min(max(0, pos), String.length(state.typing))
    Ctrl.move(state.rows, new_pos + 1) |> IO.write
    %{state | typing_pos: new_pos}
  end

  defp reset_command state do
    %{state | command: nil, command_count: ""}
  end

  # Mode transitions
  def handle_input _mode, "\e", state do  # Escape
    set_mode state, :normal
  end

  def handle_input :normal, "i", state do
    set_mode state, :insert
  end

  def handle_input :normal, "a", state do
    set_typing_pos(state, state.typing_pos + 1)
      |> set_mode(:insert)
  end

  def handle_input :normal, ":", state do
    state
      |> set_typing(":")
      |> set_mode(:insert)
  end

  def handle_input _mode, <<18>>, state do  # C-r
    redraw state
  end

  # Insert mode
  def handle_input mode, "\d", state do  # Backspace
    {pre, post} = typing_split state
    pre = String.slice(pre, 0..-2)
    draw_commandline %{
      state |
      typing: pre <> post,
      typing_pos: String.length(pre)
    }
  end

  def handle_input mode, "\r", state do  # Return
    cmd = state.typing
    parse_input cmd
    %{
      state |
      typing: "",
      typing_pos: 0
    }
  end

  def handle_input mode, "\e[A", state do  # Up arrow
    # TODO previous in command history
    state
  end

  def handle_input mode, "\e[B", state do  # Down arrow
    # TODO next in command history
    state
  end

  def handle_input mode, "\e[C", state do  # Right arrow
    set_typing_pos(state, state.typing_pos + 1)
  end

  def handle_input mode, "\e[D", state do  # Left arrow
    set_typing_pos(state, state.typing_pos - 1)
  end

  def handle_input :insert, c, state do
    {pre, post} = typing_split state
    str = pre <> c <> post
    draw_commandline %{
      state |
      typing: str,
      typing_pos: state.typing_pos + 1
    }
  end

  def handle_input mode, c, state do
    Utils.inspect c
    state
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
