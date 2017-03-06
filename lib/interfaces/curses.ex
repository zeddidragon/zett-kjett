defmodule ZettKjett.Interfaces.Curses do
  import :encurses

  @items {
    "first",
    "second",
    "third",
    "fourth"
  }

  @count tuple_size(@items)

  @standout 65536
 
  @curs_invisible 0

  def start_link do
    initscr()
    keypad 0, true
    timeout 120000

    win = newwin 10, 12, 1, 1
    box win, 0, 0
    keypad win, true
    timeout win, 120000
    noecho()
    cbreak()
    curs_set @curs_invisible

    
    highlight = 1
    for index <- 1..@count do
      if highlight == index do
        attron win, @standout
      else
        attroff win, @standout
      end
      print_item win, index - 1
    end

    refresh win
    menu_loop win, 0, 1
  end

  def menu_loop win, index, count do
    char = getch win
    print_item win, index
    index =
      case char do
        107 -> rem index - 1 + @count, @count
        106 -> rem index + 1, @count
        _ -> index
      end
    mvwaddstr win, 2, 8, to_charlist(to_string(count))

    attron win, @standout
    print_item win, index
    attroff win, @standout
    menu_loop win, index, count + 1
  end

  def print_item win, index do
    item = String.pad_leading elem(@items, index), 7
    mvwaddstr win, 1, 2 + index, to_charlist(item)
  end
end
