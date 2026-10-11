# Text sprites for art files

Sources for sprites drawn by Claude with gamekit (`/gamekit:art-draw`): one `<id>.yaml` per asset in
`assets.yaml`, one character per pixel using the keys in `palette.hex` (`P` / `p` = player color).
`gamekit draw <id>` turns one into `assets/art/<id>.png` (+ its frame files), which the game then uses
instead of the sprite's rows in `src/art/pixel_art.gd`. Nothing here is used by the game directly.
