defmodule ZettKjett.Interfaces.Curses do
  alias ZettKjett.Interfaces.Curses.{Tree, Input, Format}
  import :encurses
  @enforce_keys [:main]
  defstruct [
    main: nil,
    tree: nil,
    input: nil,
    protocol: nil,
    channel: nil,
    selected: nil,
    expanded: %{}
  ]

  def start_link do
    Task.start_link fn ->
      init()
      state = %__MODULE__{main: self()}
      {:ok, tree} = Tree.start_link state
      state = %{state | tree: tree}
      send tree, {:state, state}
      loop state
    end
  end

  def init do
    initscr()
    Format.init()
    keypad 0, true
    timeout 120000
    noecho()
  end

  def loop state do
    receive do
      {:input, code} ->
        process_input code, state
      _ ->
        :ok
    end
    loop state
  end

  def input_loop win, state do
    char = getch win
    if char > -1 do
      send state.main, {:input, char}
    end
    input_loop win, state
  end

  def process_input ?k, state do
    send state.tree, {:up}
  end

  def process_input ?j, state do
    send state.tree, {:down}
  end

  def process_input ?q, state do
    send state.tree, {:quit}
    raise "quit"
  end

  def process_input _, _ do
    :ok
  end
end

defmodule ZettKjett.Interfaces.Curses.Format do
  import :encurses
  use Bitwise

  @black   0
  @red     1
  @green   2
  @yellow  3
  @blue    4
  @magenta 5
  @cyan    6
  @white   7

  @text 0
  @protocol 1
  @channel  2
  @friend   3

  @normal     0
  @bold       bsl(1, 8 + 13)
  @underline  bsl(1, 8 + 9)
  @reverse    bsl(1, 8 + 10)
  @blink      bsl(1, 8 + 11)

  @standout 65536
  @curs_invisible 0

  def init do
    start_color()
    init_pair @protocol, @green,   @black
    init_pair @channel,  @yellow,  @black
    init_pair @friend,   @magenta, @black
    curs_set @curs_invisible
  end

  def text, do: @text 
  def protocol, do: @protocol 
  def channel, do: @channel 
  def friend, do: @friend 

  defp get_color c do
    case c do
      :test -> @text
      :protocol -> @protocol
      :channel -> @channel
      :friend -> @friend
      _ -> c
    end
  end

  def color c do
    attron bsl(get_color(c), 8)
  end
  def color win, c do
    attron win, bsl(get_color(c), 8)
  end

  def standout on do
    if on
      do attron @standout
      else attroff @standout
    end
  end

  def standout win, on do
    if on
      do attron win, @standout
      else attroff win, @standout
    end
  end
end

defmodule ZettKjett.Interfaces.Curses.Tree do
  alias ZettKjett.Interfaces.Curses.{Format}
  alias ZettKjett.Interfaces.Curses
  import :encurses

  def start_link state do
    {_x, y} = getmaxxy()
    win = newwin 16, y, 0, 0
    box win, 0, 0
    keypad win, true
    timeout win, 120000
    refresh win

    redraw win, state
    Task.start_link fn ->
      Curses.input_loop win, state
    end
    Task.start_link fn ->
      loop win, state
    end
  end

  defp loop win, state do
    state =
      receive do
        msg -> handle_message msg, win, state
      end
    loop win, state
  end

  defp handle_message {:state, newstate}, _, _ do
    newstate
  end

  defp handle_message {:up}, win, state do
    state
  end

  defp handle_message {:down}, win, state do
    state
  end
  
  defp handle_message {:quit}, win, state do
    delwin win
    state
  end

  defp redraw win, state do
    items = for protocol <- ZettKjett.protocols, do: {protocol, :protocol, 0}
    print_items items, win, state
  end

  def label type, item do
    case type do
      :protocol -> to_string item
      _ -> item.name
    end
  end

  defp print_items items, win, state, index \\ 0
  defp print_items [], win, _, _ do
    refresh win
  end
  defp print_items [{item, type, indent} | items], win, state, index do
    if state.selected == item, do: Format.standout win
    Format.color win, type
    mvwaddstr win, indent + 1, index + 1, to_charlist(label(type, item))
    if state.selected == item, do: Format.standout win, false

    print_items items, win, state, index + 1
  end
end
