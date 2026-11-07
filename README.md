# Folio Deck

A wallpaper picker for the Omarchy shell: a deck of paint-chip cards. Your
wallpapers fan out like a hand along the foot of the screen; behind them the
whole screen previews the card in front at full size, and the picker's own
glass and accents take on that card's colours, so browsing is trying each
wallpaper on.

Each card is dressed in the colours its wallpaper would bring (its surface,
ink and accent) and shows the picture, its colour roles (Primary, Secondary,
Tertiary, Container, Surface) with their hex codes, and its name, format,
size and file weight.

The ribbon under the header is the whole deck in colour: a bracket marks the
cards in hand, ticks the favourites, a dot the one in use. Hover it for a
glimpse; click or drag along it to go there.

Choosing a card: it leaves the hand for the middle of the screen, lights up
as it's set, then its picture grows into the wallpaper and the picker goes.
Turn that off in the settings (the gear) to set cards at once and keep the
deck open.

## Keys

| Key                     | Action                                        |
| ----------------------- | --------------------------------------------- |
| `←` `→` / `H` `L`       | Browse                                        |
| `PageUp` `PageDown`     | Jump 8 cards                                  |
| `Home` `End`            | First / last card                             |
| `Enter`                 | Set the front card                            |
| `F`                     | Toggle favourite                              |
| `S`                     | Cycle sort: name → colour → newest            |
| `R`                     | Jump to a random card                         |
| `Space`                 | Peek: hold to see the picture clear, tap to keep it clear |
| `Tab` / `Shift+Tab`     | Cycle source (wallpapers only)                |
| `T`                     | Switch between wallpapers and themes          |
| `Esc`                   | Close (or leave peek / settings first)        |

Mouse: scroll or drag anywhere to browse, click a card to bring it to the
front, click the front card (or double-click any card) to set it, click the
picture itself to peek.

## Themes (`T`)

Press `T` (or pick **Themes** in the header) to swap the hand for your Omarchy
themes. Each card crossfades through the theme's preview and every wallpaper
it has (a dot for each), wears the theme's own colours, says whether it is
light or dark and where it comes from (built-in or yours), and shows five
chips read from its `colors.toml`. The backdrop shows the theme's preview.
`Enter` applies it with `omarchy-theme-set`.

Open straight into a mode from a terminal:

```
omarchy-shell folio-deck themes       # open on themes
omarchy-shell folio-deck wallpapers   # open on wallpapers
omarchy-shell folio-deck toggle       # open in the last mode, or close
omarchy-shell folio-deck close | keep | step <n> | peek | mode | front
omarchy-shell folio-deck source theme|all|folder|favourites   # switch source
omarchy-shell folio-deck count        # source and number of cards
```

`themes` and `wallpapers` switch an open deck to that mode, and close it if
it is already showing that mode, so each one works as a key binding by itself.
The host's form still works:
`omarchy-shell shell call folio.deck themes ""` (the empty argument is
required) and `omarchy-shell shell toggle folio.deck theme` (or `wallpaper`,
`all`, `folder`, `favourites`, or JSON: `'{"mode":"wallpaper","source":"all"}'`).

## Sources (`Tab`)

- **This theme** – wallpapers of the current theme
- **All themes** – wallpapers from every theme
- **Folder** – pictures in your own wallpaper folder (set it under the gear)
- **Favourites** – cards you marked with `F` or the heart

## Sort (`S`)

- **name** – alphabetical
- **colour** – by the hue of each picture's primary colour (the deck becomes a spectrum)
- **newest** – most recently modified first

## Settings

Kept in `~/.config/folio-deck/settings.json` (a hand edit applies at once):
`folder`, `favourites`, `animateChoice`, and the last `mode`, `source` and
`sort`. Palettes are cached in `~/.cache/folio-deck/palettes.json`.

`FOLIO_DECK_DRY=1` in the shell's environment plays everything but sets
nothing and leaves the keyboard alone (drive it over IPC), for testing.
