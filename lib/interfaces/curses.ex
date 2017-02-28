defmodule ZettKjett.Interfaces.Curses do
  import ExNcurses

  @items {
    "first",
    "second",
    "third"
  }

  def start_link do
    initscr()
    win = initwin 10, 12, 1, 1
    box win, 0, 0
    
    highlight = 0
    for i <- 0..2 do
      if highlight == i do
        wattron win, A_STANDOUT
      else
        wattroff win, A_STANDOUT
      end
      print_item win, 
      item = String.pad_leading 
      mvwprintf win, i + 1, 2, "%s", item
    end

    wrefresh win
    noecho()
    curs_set 0

    menu_loop win, 0
  end

  def menu_loop win, index do
    char = wgetchar win

    print_item index
    index =
      case char do
        'j' -> index - 1
        'k' -> index + 1
        _ -> index
      end

    wattron win, A_STANDOUT
    print_item index
    wattroff win, A_STANDOUT

    menu_loop win, index
  end

  def print_item win, index do
    item = String.pad_leading elem(@items, index), 7
    mwprintf win, index + 1, 2, "%s", item
  end
end
