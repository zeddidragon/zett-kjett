defmodule ZettKjett.Interfaces.ZettSH.State do
  defstruct [
    rows: 1, # Terminal height
    cols: 1, # Terminal width
    expanded: %{}, # Which items in the tree are expanded
    system_messages: [], # Messages from ZettSH to show in chat history
    typing: [""], # Currently typed message
    typing_row: 0, # Cursor row in command line
    typing_col: 0, # Cursor column in command line
    mode: :normal, # Overall mode
    command: nil, # Currently prepared normal-mode command
    command_count: "",  # Repeats for normal-mode commands
    motion: nil, # Currently prepared motion
    motion_count: "", # Repeats for motion
    last_find: nil # Last f, F, t or T that was executed
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
  @newline "\n\r"
  @nonword ~r/\W+/
  @blank ~r/\s+/
  @nonblank ~r/\S+/

  @debug_text "first line
    Four scores and seven years ago
    I did this multiline thing to check out multiline functionality
    And it was awesome
          Maybe

    C'mon starsscream now ,break it.down
    I hope
    Additionally, this is a line that is so long it will hopefully stretch across multiple lines and teach me to do stuff that involves multiple lines but I guess we'll just have to see about that maybe let's copy-paste it for good measure while we're at it -- Additionally, this is a line that is so long it will hopefully stretch across multiple lines and teach me to do stuff that involves multiple lines but I guess we'll just have to see about that maybe let's copy-paste it for good measure while we're at it
      Tessst
  "

  @modes ["insert", "normal", "visual"]
  def start_link do
    config = (Config.get[:Interfaces] || %{})[:ZettSH] || %{}
    mode = config[:mode]
    mode =
      cond do
        mode in @modes ->
          String.to_atom mode
        !mode ->
          :normal
        true ->
          valid = Enum.join @modes, ", "
          raise ~s(Invalid mode "#{mode}". Valid modes are: [#{valid}])
      end
    #state = %State{mode: mode, typing: String.split(@debug_text, "\n")}
    state = %State{mode: :normal}

    Task.start_link fn ->
      Port.open({:spawn, "tty_sl -c -e"}, [:binary, :eof])
      state = redraw state
      message_loop state
    end
  end

  defp system message do
    time = Utils.now
    msg = %Message{
      id:  "system|#{Utils.format_timestamp(time)}",
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
      id:  "error|#{Utils.format_timestamp(time)}",
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
    "|#{@newline}" <>
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

  defp status(%State{mode: :normal} = state) do
    "#{state.command_count}#{state.command}#{state.motion_count}#{state.motion}"
  end

  defp status(%State{mode: :insert} = _state) do
    me = ZettKjett.me
    if me do
      "<#{ZettKjett.protocol}>/ #{me.name}"
    else
      "<no protocol selected>"
    end
  end

  def draw_statusbar state do
    str =
      Ctrl.save_cursor() <>
      Ctrl.move(command_row(state) - 1, 0) <>
      ANSI.color(0, 0, 0) <>
      ANSI.color_background(1, 1, 1) <>
      String.pad_trailing(status(state), state.cols) <>
      ANSI.default_color <>
      ANSI.default_background <>
      Ctrl.load_cursor
    IO.write str
    state
  end

  def history_height state do
    # Leave room for command line and status
    state.rows - command_height(state) + 1
  end

  def history_width state do
    state.cols - @chat_x
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
      |> Enum.join(@newline <> Ctrl.right(@chat_x))
    str =
      Ctrl.save_cursor() <>
      Ctrl.move(0, @chat_x + 1) <>
      history <>
      Ctrl.load_cursor()
    IO.write str
    state
  end

  def draw_commandline state do
    start = command_row(state)
    row = start + state.typing_row
    col = min(state.typing_col, typing_cols(state))
    content = state.typing
      |> Enum.flat_map(&cut_string(&1, state.cols))
      |> Enum.map(&String.pad_trailing(&1, state.cols, " "))
      |> Enum.join(@newline)
    str =
      Ctrl.move(start, 0) <>
      ANSI.clear_line <>
      content
    IO.write str
    set_typing_pos(state, state_pos(state))
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

  def typing_split(state) do
    state
      |> typing_line()
      |> String.split_at(state.typing_col)
  end

  defp set_mode state, mode do
    offset = if state.mode == :insert do -1 else 0 end
    col = max(0, state.typing_col + offset)
    %{state | mode: mode}
      |> set_typing_pos({state.typing_row, col})
      |> reset_command()
      |> draw_statusbar()
      |> draw_commandline()
  end

  defp set_typing state, str do
    %{ state |
      typing: [str],
      typing_col: String.length(str),
      typing_row: 0
    }
  end

  defp wrapped_width state, line do
    line
      |> String.length
      |> div(state.cols)
      |> Kernel.+(1)
  end

  defp command_height(state, range) do
    command_height(%{state | typing: Enum.slice(state.typing, 0, range)})
  end
  defp command_height state do
    state.typing
      |> Enum.map(&wrapped_width(state, &1))
      |> Enum.sum()
  end

  defp command_row state do
    state.rows - command_height(state) + 1
  end

  defp restrict(state, {row, col}) do
    row = min(row, length(state.typing) - 1)
    col = state
      |> typing_cols(row)
      |> min(col)
      |> max(0)
    {row, col}
  end

  defp set_typing_pos state, {row, col} do
    state = %{ state |
      typing_row: row,
      typing_col: col
    }
    col = min(col, typing_cols(state) - 1)
    row = command_height(state, row) + div(col, state.cols)
    Ctrl.move(command_row(state) + row, rem(col, state.cols) + 1) |> IO.write
    state
  end

  defp parse_count(n) when is_number(n), do: n
  defp parse_count("" = str), do: 1
  defp parse_count(str), do: Utils.parse_int(str)

  defp motion_count state do
    parse_count state.motion_count
  end


  defp typing_line(state), do: typing_line(state, state.typing_row)
  defp typing_line(state, row) do
    Enum.at state.typing, row
  end

  defp typing_cols(state, row \\ nil) do
    len = state
      |> typing_line(row || state.typing_row)
      |> String.length
    if state.mode == :insert do len + 1 else len end
  end

  defp state_pos(state), do: {state.typing_row, state.typing_col}
  defp state_screen(state) do
    pos = state_pos(state)
    pos_to_screen(state, pos)
  end

  defp pos_to_screen(state, {row, col}) do
    y = command_height(state, row) + div(col, state.cols)
    x = rem(col, state.cols)
    {y, x}
  end

  defp y_to_row(state, lines, targety, y \\ 0, row \\ 0)
  defp y_to_row(state, [line], targety, y, row), do: {row, y}
  defp y_to_row(state, [line | lines], targety, y, row) do
    next_y = line
      |> String.length()
      |> div(state.cols)
      |> Kernel.+(y + 1)
    if next_y > targety do
      {row, y}
    else
      y_to_row(state, lines, targety, next_y, row + 1)
    end
  end

  defp screen_to_pos(state, {y, x}) do
    {row, base_y} = y_to_row(state, state.typing, y)
    diff = y - base_y
    col = diff * state.cols + x
    {row, col}
  end

  defp index_to_row(state, lines, target_i, i \\ 0, row \\ 0)
  defp index_to_row(state, [], target_i, i, row), do: {row - 1, i - 1}
  defp index_to_row(state, [line | lines], target_i, i, row) do
    next_i = i + String.length(line)
    if next_i > target_i do
      {row, target_i - i}
    else
      index_to_row(state, lines, target_i, next_i, row + 1)
    end
  end
  
  defp index_to_pos(state, i) do
    {row, remained} = index_to_row(state, state.typing, i)
  end

  defp compound_motion(state, ms, offset),
    do: compound_motion(%{state | motion_count: motion_count(state) - 1}, ms)
  defp compound_motion(state, [m]),
    do: motion(state, m)
  defp compound_motion(state, [m | ms]) do
    {row, col} = motion(state, m)
    state = %{
      state |
      typing_row: row,
      typing_col: col,
      motion_count: ""
    }
    compound_motion(state, ms)
  end

  # Left
  defp motion(state, c) when c in ~w(h \e[D \b \d) do
    cols = typing_cols(state)
    count = motion_count(state)
    col = max(0, min(cols - 1, state.typing_col) - count)
    {state.typing_row, col}
  end

  # Right
  defp motion(state, c) when c in ["l", "\e[C", " "] do
    cols = typing_cols(state)
    count = motion_count(state)
    col =
      if cols < state.typing_col do
        state.typing_col
      else
        min(cols - 1, state.typing_col + count)
      end
    {state.typing_row, col}
  end

  # Up
  defp motion(state, c) when c in ["k", "\e[A", <<16>>] do
    count = motion_count(state)
    row = max(0, state.typing_row - count)
    {row, state.typing_col}
  end

  # Down
  defp motion(state, c) when c in ["j", "\n", "\e[B", <<14>>] do
    count = motion_count(state)
    rows = length(state.typing)
    row = min(rows - 1, state.typing_row + count)
    {row, state.typing_col}
  end

  # Up screen line
  defp motion(state, c) when c in ~w(gk g\e[A) do
    count = motion_count(state)
    {y, x} = state_screen(state)
    screen_to_pos(state, {y - count, x})
  end

  # Down screen line
  defp motion(state, c) when c in ~w(gj g\e[B) do
    count = motion_count(state)
    {y, x} = state_screen(state)
    screen_to_pos(state, {y + count, x})
  end

  # Next line
  defp motion(state, c) when c in ~w(+ \r) do
    compound_motion(state, ~w(j ^))
  end

  # Previous line
  defp motion(state, "-") do
    compound_motion(state, ~w(k ^))
  end

  # Up and first non-blank
  defp motion(state, "-"), do: compound_motion(state, ~w(k ^))

  # Down and first non-blank
  defp motion(state, "+"), do: compound_motion(state, ~w(j ^))
  defp motion(state, "\r"), do: motion(state, "+")

  # Down to first non-blank
  defp motion(state, "_"), do: compound_motion(state, ~w(j, ^), -1)

  # Jump to bottom, first non-blank
  defp motion(%State{motion_count: ""} = state, "G") do
    motion(%{state | typing_row: length(state.typing) - 1}, "^")
  end

  # Jump to row, first non-blank
  defp motion(state, c) when c in ~w(G gg \e[1;5H) do
    row = state
      |> motion_count()
      |> min(length(state.typing))
    motion(%{state | typing_row: row - 1}, "^")
  end

  # Jump to row, last grapheme
  defp motion(state, "\e[1;5F"), do: compound_motion(state, ~w(gg $))

  # Jump to grapheme
  defp motion(state, "go") do
    index_to_pos(state, motion_count(state) - 1)
  end

  # Jump to percent of lines, then first non-blank
  defp motion(state, "%") do
    count = motion_count(state)
    if count > 100 do
      state_pos(state)
    else
      row = div((length(state.typing) - 1) * count, 100)
      motion(%{state | typing_row: row}, "^")
    end
  end

  # Beginning of line
  defp motion(state, g) when g in ~w(0 \e[H) do
    {state.typing_row, 0}
  end

  # First non-blank
  defp motion(state, "^") do
    line = typing_line(state)
    [indent | _] = line
      |> String.split(@nonblank, parts: 2)
    {state.typing_row, String.length(indent)}
  end

  # Down to end of line
  defp motion(%State{motion_count: ""} = state, c) when c in ~w($ \e[F),
    do: {state.typing_row, typing_cols(state) - 1}
  defp motion(state, c) when c in ~w($ \e[F),
    do: compound_motion(state, ~w(j $), -1)

  # Down to beginning of screen
  defp motion(state, c) when c in ~w(g0 g\e[H) do
    {y, x} = state_screen(state)
    count = motion_count(state)
    pos = screen_to_pos(state, {y + count - 1, 0})
    restrict(state, pos)
  end

  # Down to end of screen
  defp motion(state, c) when c in ~w(g$ g\e[F) do
    {y, x} = state_screen(state)
    count = motion_count(state)
    pos = screen_to_pos(state, {y + count - 1, state.cols - 1})
    restrict(state, pos)
  end

  # First non-blank on screen, no vertical motion
  defp motion(state, "g^") do
    {y, x} = state_screen(state)
    col = min(typing_cols(state) - 1, state.typing_col)
    base_x = div(col, state.cols) * state.cols
    {_pre, line} = state |>
      typing_line() |>
      String.split_at(base_x)
    [blank | _remainder] = String.split(line, @nonblank, parts: 2)
    x = String.length(blank)
    pos = screen_to_pos(state, {y, x})
    restrict(state, pos)
  end

  # Down to last non-blank
  defp motion(%State{motion_count: ""} = state, "g_") do
    line = typing_line(state)
    [trailing | _] = line
      |> String.reverse
      |> String.split(@nonblank, parts: 2)
    {state.typing_row, String.length(line) - String.length(trailing)}
  end
  defp motion(state, "g_"),
    do: compound_motion(state, ~w(j g_), -1)

  # Middle of row
  defp motion(state, "gm") do
    {y, _x} = state_screen(state)
    pos = screen_to_pos(state, {y, div(state.cols, 2)})
    restrict(state, pos)
  end

  # Jump to column
  defp motion(state, "|"),
    do: {state.typing_row, motion_count(state)}

  # Find char
  defp motion(state, "f", c) do
    count = motion_count(state)
    {_pre, post} = typing_split(state)
    case post |> String.slice(1..-1) |> Utils.index(c, count) do
      {:error, _reason} ->
        state_pos(state)
      {:ok, index} ->
        {state.typing_row, state.typing_col + index}
    end
  end

  # Find char backwards
  defp motion(state, "F", c) do
    count = motion_count(state)
    {pre, _post} = typing_split(state)
    case pre |> String.reverse |> Utils.index(c, count) do
      {:error, _reason} ->
        state_pos(state)
      {:ok, index} ->
        {state.typing_row, state.typing_col - index}
    end
  end

  # Till char
  defp motion(state, "t", c) do
    col = state.typing_col
    case motion(state, "f", c) do
      {_, ^col} ->  # No match
        state_pos(state)
      {_, col} ->
        {state.typing_row, col - 1}
    end
  end

  # Till char backwards
  defp motion(state, "T", c) do
    col = state.typing_col
    case motion(state, "F", c) do
      {_, ^col} ->  # No match
        state_pos(state)
      {_, col} ->
        {state.typing_row, col + 1}
    end
  end

  # Repeat last find when no last find exists
  defp motion(%State{last_find: nil} = state, m) when m in ~w(; ,),
    do: state_pos(state)

  # Repeat last find
  defp motion(state, ";") do
    {m, c} = state.last_find
    motion(state, m, c)
  end

  # Repeat last find backwards
  defp motion(state, ",") do
    {m, c} = state.last_find
    m =
      case m do
        "f" -> "F"
        "F" -> "f"
        "t" -> "T"
        "T" -> "t"
      end
    motion(state, m, c)
  end

  defp next_match(state, pattern, count) do
    {_pre, post} = typing_split(state)
    case Utils.next_pattern_match(post, pattern, count) do
      {:error, _, n} ->
        row = state.typing_row + 1
        if row >= length(state.typing) do
          {:error, {state.typing_row, typing_cols(state) - 1}, ""}
        else
          next_match(%{state | typing_col: 0, typing_row: row}, pattern, n)
        end
      {:ok, index, frag} ->
        if String.match?(frag, @blank) do
          [blank, nonblank, _] =
            String.split(frag, @nonblank, parts: 2, include_captures: true)
          index = index + String.length(blank)
          {:ok, {state.typing_row, state.typing_col + index}, nonblank}
        else
          {:ok, {state.typing_row, state.typing_col + index}, frag}
        end
    end
  end

  defp previous_match(state, pattern, count) do
    {pre, _post} = typing_split(state)
    case pre |> String.reverse() |> Utils.next_pattern_match(pattern, count) do
      {:error, _, n} ->
        if state.typing_row == 0 do
          {:error, {0, 0}, ""}
        else
          row = state.typing_row - 1
          col = typing_cols(state, row)
          state = %{state | typing_col: col, typing_row: row}
          previous_match(state, pattern, n)
        end
      {:ok, index, frag} ->
        if String.match?(frag, @blank) do
          [blank, nonblank, _] =
            String.split(frag, @nonblank, parts: 2, include_captures: true)
          index = index + String.length(blank)
          {:ok, {state.typing_row, state.typing_col - index}, nonblank}
        else
          {:ok, {state.typing_row, state.typing_col - index}, frag}
        end
    end
  end

  defp cursor_on?(state, pattern) do
    state
      |> typing_line()
      |> String.at(state.typing_col)
      |> String.match?(pattern)
  end

  defp next_pattern_start(state, pattern) do
    count = motion_count(state) +
      if cursor_on?(state, @blank) do 0 else 1 end
    state
      |> next_match(pattern, count)
      |> elem(1)
  end

  # Next beginning of word or nonblank
  defp motion(state, c) when c in ~w(w \e[1;2C),
    do: next_pattern_start(state, @nonword)

  # Next beginning of nonblank
  defp motion(state, c) when c in ~w(W \eOC \e[1;5C),
    do: next_pattern_start(state, @blank)

  defp next_pattern_end(state, pattern) do
    state = %{state | typing_col: state.typing_col + 1}
    case next_match(state, pattern, motion_count(state)) do
      {:error, pos, _} -> pos
      {:ok, {row, col}, frag} -> {row, col + String.length(frag) - 1}
    end
  end

  # Next end of word
  defp motion(state, "e"), do: next_pattern_end(state, @nonword)

  # Next end of nonblank
  defp motion(state, "E"), do: next_pattern_end(state, @blank)

  defp previous_pattern_start(state, pattern) do
    case previous_match(state, pattern, motion_count(state)) do
      {:error, pos, _} -> pos
      {:ok, {row, col}, frag} -> {row, col - String.length(frag)}
    end
  end

  # Previous beginning of word or nonblank
  defp motion(state, c) when c in ~w(b \e[1;2D),
    do: previous_pattern_start(state, @nonword)

  # Previous beginning of nonblank
  defp motion(state, c) when c in ~w(B \e[1;5D),
    do: previous_pattern_start(state, @blank)

  defp previous_pattern_end(state, pattern) do
    count = motion_count(state) +
      if cursor_on?(state, @blank) do 0 else 1 end
    {_, {row, col}, _} = previous_match(state, pattern, count)
    {row, max(col - 1, 0)}
  end

  # Previous end of word
  defp motion(state, "ge"), do: previous_pattern_end(state, @nonword)

  # Previous end of nonblank
  defp motion(state, "gE"), do: previous_pattern_end(state, @blank)

  defp reset_command state do
    %{ state |
      command: nil,
      command_count: "",
      motion: nil,
      motion_count: ""
    }
  end

  # Normal mode
  @find ~w(f F t T)
  def handle_input(:normal, c, %State{motion: m} = state) when m in @find do
    state = %{state | last_find: {m, c}}
    execute(state, motion(state, state.motion, c))
  end

  @premotions ~w(g f F t T)
  def handle_input(:normal, c, %{motion: nil} = state) when c in @premotions do
    draw_statusbar(%{state | motion: c})
  end

  @gmotions ~w(g j k h m _ 0 ^ $ o e E \e[H \e[F)
  def handle_input(:normal, c, %{motion: "g"} = state) when c in @gmotions do
    execute(state, motion(state, "g" <> c))
  end

  @motions [
    " ", "\r", "\n", "\b",
    <<14>>, <<16>> |
    ~w(
      h j k l
      ^ $ + - _
      G | ; , %
      w W e E b B \e[1;2C \e[1;5C \e[1;2D \e[1;5D
      \e[H \e[F \e[A \e[B \e[C \e[D \e[1;5H \e[1;5F
    )
  ]
  def handle_input(:normal, c, state) when c in @motions do
    execute(state, motion(state, c))
  end

  def handle_input(:normal, "0", %State{motion_count: ""} = state) do
    execute(state, motion(state, "0"))
  end

  def handle_input(:normal, n, state) when n in ~w(0 1 2 3 4 5 6 7 8 9) do
    draw_statusbar(%{state | motion_count: state.motion_count <> n})
  end

  # Insert mode
  def handle_input(_mode, "\d", state) do  # Backspace
    {pre, post} = typing_split(state)
    pre = String.slice(pre, 0..-2)
    draw_commandline %{
      state |
      typing: pre <> post,
      typing_col: String.length(pre)
    }
  end

  def handle_input(:insert, "\r", state) do  # Return
    cmd = Enum.join(state.typing, "\r\n")
    parse_input cmd
    %{ state |
      typing: [""],
      typing_col: 0,
      typing_row: 0
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
    {pre, post} = typing_split(state)
    typing = List.replace_at(
      state.typing,
      state.typing_row,
      pre <> c <> post
    )
    draw_commandline %{
      state |
      typing: typing,
      typing_col: state.typing_col + 1
    }
  end

  # Mode transitions
  def handle_input _mode, "\e", state do  # Escape
    set_mode(state, :normal)
  end

  def handle_input :normal, "i", state do
    set_mode(state, :insert)
  end

  def handle_input :normal, "a", state do
    state = set_mode(state, :insert)
    set_typing_pos(state, motion(state, "l"))
  end

  def handle_input :normal, "I", state do
    state = set_mode(state, :insert)
    set_typing_pos(state, motion(state, "^"))
  end

  def handle_input :normal, "A", state do
    state = set_mode(state, :insert)
    set_typing_pos(state, motion(state, "$"))
  end

  def handle_input :normal, ":", state do
    state = set_mode(state, :insert)
    set_typing(state, ":")
  end

  def handle_input _mode, <<18>>, state do  # C-r
    redraw state
  end

  def execute(%State{command: nil} = state, to_pos) do
    set_typing_pos(state, to_pos)
      |> reset_command()
      |> draw_statusbar()
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
