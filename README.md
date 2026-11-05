# Folio Deck

A wallpaper picker for the Omarchy shell. Your wallpapers fan out as a hand of
cards along the bottom of the screen. Browsing a card previews it live on the
real background; keep one to set it, or put everything back.

Each card shows the picture, its Material colour roles (Primary, Secondary,
Tertiary, Container, Surface), and its name, format, size and file weight.

## Keys

| Key                | Action                                   |
| ------------------ | ---------------------------------------- |
| `←` `→` / `H` `L`  | Browse                                   |
| `PageUp` `PageDown`| Jump 8 cards                             |
| `Home` `End`       | First / last card                        |
| `Enter`            | Keep the front card as the wallpaper     |
| `F`                | Toggle favourite                         |
| `S`                | Cycle sort: name → colour → newest       |
| `R`                | Jump to a random card                    |
| `Tab`              | Cycle source (see below; wallpapers only)|
| `T`                | Switch between wallpapers and themes     |
| `Esc`              | Close and put the original wallpaper back|

Mouse: scroll to browse, click a card to bring it to the front, click the front
card (or double-click any card) to keep it.

## Themes (`T`)

Press `T` to swap the hand for your Omarchy themes. Each card shows the theme's
preview picture (each card cycles through the preview and every wallpaper
the theme has, a dot for each), whether it is light or dark, where it comes from (built-in or
yours), and five chips read from its `colors.toml`. `Enter` applies it with
`omarchy-theme-set`; browsing does not retint the desktop, since that is heavy.
Open straight into a mode from a terminal:

```
omarchy-shell folio-deck themes       # open on themes
omarchy-shell folio-deck wallpapers   # open on wallpapers
omarchy-shell folio-deck toggle       # open in the last mode, or close
omarchy-shell folio-deck close | keep | step <n> | mode | front
```

`themes` and `wallpapers` switch an open deck to that mode, and close it if
it is already showing that mode, so each one works as a key binding by itself.
Sort (`S`) works here too. The host's form still works:
`omarchy-shell shell call folio.deck themes ""` (the empty argument is
required) and `omarchy-shell shell toggle folio.deck theme` (or `wallpaper`,
or JSON: `'{"mode":"theme"}'`). The host's toggle closes an open deck
whatever mode you name; `omarchy-shell folio-deck themes` switches it instead.

## Sources (`Tab`)

- **This theme** – wallpapers of the current theme
- **All themes** – wallpapers from every theme
- **My folder** – pictures in your own wallpaper folder
- **Favourites** – cards you marked with `F`

## Sort (`S`)

- **name** – alphabetical
- **colour** – by the hue of each picture's primary colour
- **newest** – most recently modified first
