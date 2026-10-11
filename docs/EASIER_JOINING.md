# Easier joining (parked)

**Status (2026-10-11):** parked by the owner. Friends keep joining with the host's direct IP invite (`IP:port`, UDP 7777 forwarded, UPnP tried automatically). This page keeps the research in case hosting a join server becomes worth it.

**The problem:** the host has to forward a port. A join system would let the host press Host, get a short code, and have friends type it, with no port forwarding for anyone.

## Owner constraints
- **No Steam** for now (Steamworks costs $100 and the game isn't going on Steam).
- **No money:** no paid server.
- **A home lab is available** if hosting ever happens (see below).

## Options compared

| | **noray join codes** | **Epic Online Services** | **VPN guide** |
|---|---|---|---|
| How it works | A small matchmaking server ([noray](https://github.com/foxssake/noray), via the [netfox.noray addon](https://godotengine.org/asset-library/asset/2376), MIT) connects host and friends directly (NAT punch-through) and relays the game when that fails | Epic's servers do punch-through and relaying; not tied to the Epic store; players need no Epic account | Everyone installs Tailscale or ZeroTier; today's IP invite works over it |
| Friends' experience | Type a short code | Type a short code | Install and sign into a VPN app once |
| Code change | Small: keeps our ENet networking, adds the addon | Big: the [GD-EOS](https://github.com/Daylily-Zeleen/GD-EOS) native plugin replaces ENet with an EOS peer | None (a guide in `tools/README-friends.txt`) |
| Cost | Needs an always-on server: free on a home lab, ~$4-6/month on a VPS, or a free cloud tier (Oracle; signup needs a card, free machines get reclaimed) | Free | Free |
| Setup for the owner | The server (Docker) and a few router port forwards | A free Epic developer account, plus an organization and product in Epic's developer portal | None |
| Risks | Server upkeep; relayed games add a little lag | The plugin must support our Godot version (4.7); a broken plugin after an engine update breaks joining | Friction for each new friend |

**Claude's recommendation:** noray on the home lab. It's free, keeps the tested ENet code, and the IP invite stays as a fallback when the server is down. Without hosting: check first that GD-EOS works with Godot 4.7 on Windows (a short test that changes nothing in the game) before committing to Epic; if it doesn't, write the VPN guide.

## noray on the home lab: what it needs
- **Ports forwarded on the router once** (as for 7777 today): a TCP port for setting up games, a UDP port for finding each player's address, and a UDP port range for relays. Check the exact defaults in noray's README (from memory, roughly TCP 8890, UDP 8809 and UDP 49152-51200; verify before forwarding).
- **A stable name:** home IPs change, so a free dynamic DNS name (DuckDNS or the router's own) such as `medieval.duckdns.org`, baked into the game.
- **A real public IP, not CGNAT.** Friends can already join the owner with port forwarding, so it almost certainly is one (check: the router's WAN IP equals what whatismyip shows).
- **The lab must be on during play.** If noray can't be reached, the game falls back to the IP invite.
- **Safety:** run noray in a container with only its ports open.
- **Playing from home:** a PC inside the house may not reach the house's own public address (no NAT loopback on some routers). The game should then use the lab's LAN address.

## Game-side plan (when picked up)
1. Add `netfox.noray` (check it supports Godot 4.7); a noray address setting (default: the DNS name).
2. Host: register with noray, show the short code in the lobby and invite line (copy with F1 like today).
3. Join dialog: accept a code as well as `IP:port` (`Net` invite parsing).
4. Connect via punch-through, fall back to noray's relay, fall back to telling the player to use the IP invite.
5. Keep the online smoke test working (`--local-only` must skip noray) and add a run against a local noray server.
6. `tools/README-friends.txt` and `docs/PLAYTEST.md`: how to join with a code.
