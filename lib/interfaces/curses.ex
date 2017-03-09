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
      state = %__MODULE__{
        main: self(),
        selected: {hd(ZettKjett.protocols), :protocol}
      }
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
    endwin()
    raise "quit"
  end

  @enter 13
  def process_input @enter, state do
    select state.selected
  end

  def process_input _, _ do
    :ok
  end

  def select {} do 
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
  @protocol 2
  @channel  4
  @friend   6

  @normal     0
  @bold       1 <<< (8 + 13)
  @underline  1 <<< (8 + 9)
  @reverse    1 <<< (8 + 10)
  @blink      1 <<< (8 + 11)

  @curs_invisible 0

  def init do
    start_color()
    init_pair @protocol, @green,   @black
    init_pair @channel,  @yellow,  @black
    init_pair @friend,   @magenta, @black
    init_pair @protocol + 1, @black, @green
    init_pair @channel + 1,  @black, @yellow
    init_pair @friend + 1,   @black, @magenta
    curs_set @curs_invisible
  end

  defp get_color c, opts \\ [] do
    ret = case c do
      :text -> @text
      :protocol -> @protocol
      :channel -> @channel
      :friend -> @friend
      _ -> c
    end
    if opts[:highlight] do ret + 1
    else ret
    end
  end

  def color(c) do
    color(c, [])
  end
  def color(c, opts) when is_list(opts) do
    color = get_color(c, opts)
    attron(get_color(c) <<< 8)
  end
  def color(win, c, opts \\ []) when is_atom(c) do
    attron(win, get_color(c, opts) <<< 8)
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
    items = for protocol <- ZettKjett.protocols, do: {protocol, :protocol}
    print_items items, win, state
  end

  def label {item, type} do
    case type do
      :protocol -> to_string item
      _ -> item.name
    end
  end

  def indent {item, type} do
    case type do
      :protocol -> 0
      _ -> 1
    end
  end

  defp print_items items, win, state, index \\ 0
  defp print_items [], win, _, _ do
    refresh win
  end
  defp print_items [{item, type} | items], win, state, index do
    Format.color win, type, highlight: {item, type} == state.selected
    str = {item, type}
      |> label
      |> String.pad_trailing(14)
      |> to_charlist
    mvwaddwch win, 1, index + 1, 0x2265
    mvwaddstr win, indent({item, type}) + 2, index + 1, str

    print_items items, win, state, index + 1
  end
end
