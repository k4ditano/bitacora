#!/usr/bin/env bash
# Bitácora with agents, in a headless pleamar-wm session of its own (HOME, XDG_* and XDG_RUNTIME_DIR in
# tmp/, nothing of the real session's): its shells' agents and their companions' tabs, an agent beside a
# pane and wired to it, «Send to…», a tab brought to the front from outside, and `-e`.
# The agent is a stand-in: a script called `claude` that says it works, then that it is ready.
#   tests/agents.sh OUT        (WM_BIN, PLEAMAR_BIN: the pleamar-wm and pleamar to use)
set -uo pipefail
OUT=$(mkdir -p "${1:?OUT}" && cd "$1" && pwd)
REPO=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
WM=${WM_BIN:?WM_BIN: a pleamar-wm with term pair}
PL=${PLEAMAR_BIN:?PLEAMAR_BIN: a pleamar, to speak to the windows}
BIN="$REPO/target/release/bitacora"
mkdir -p "$REPO/tmp"
T=$(mktemp -d "$REPO/tmp/ag.XXXXXX")
mkdir -p "$T"/{home,config/pleamar,data,state,cache,bin,work} && mkdir -m 0700 "$T/runtime"
# The session's own hands, for the wheel (pleamar-wm agent scroll): as a mouse turns it.
echo "agent on" > "$T/config/pleamar/session.conf"
# The stand-in agent.
cat > "$T/bin/claude" <<'AGENT'
#!/bin/bash
printf '\033]0;\xe2\x97\x90 Probando el cable\007'
echo "stand-in agent: working"
sleep 5
printf '\033]0;\xe2\x9c\xb3 Probando el cable\007'
echo "stand-in agent: ready"
cat
AGENT
chmod +x "$T/bin/claude"
# A companion's card, as Calima keeps it.
mkdir -p "$T/data/pleamar/calima"
printf '{"nombre":"Sonda de prueba","color":2,"glifo":[14,21,10,10,17],"cli":"claude","carpeta":"~"}\n' > "$T/data/pleamar/calima/caravana-probe.json"
echo "a line to select and send" > "$T/work/notes.txt"
# `-e`, later: a window whose first shell is a command.
cat > "$T/bin/run-e" <<RUNE
#!/bin/sh
# (When the test says: a new window makes the others smaller, and a terminal made smaller loses what is selected.)
while [ ! -e $T/go-e ]; do sleep 0.3; done
exec env BITACORA_UI_DIR=$REPO/ui $BIN -e sh -c 'echo "it ran: \$((6*7))"; sleep 600'
RUNE
chmod +x "$T/bin/run-e"
# Bitácora as a companion's terminal, what it says kept.
printf '#!/bin/sh\nexec %s "$@" 2>> %s\n' "$BIN" "$T/companion.log" > "$T/bin/bitacora-c"
chmod +x "$T/bin/bitacora-c"
cat > "$T/autostart" <<AUTO
env BITACORA_UI_DIR=$REPO/ui $BIN $T/work
$T/bin/run-e
AUTO
# Nothing of the session it is run from: every PLEAMAR_* goes (PLEAMAR_CONFIG would put the mailboxes and
# the kept canvas in the real session's state, and a letter would reach a real companion).
for v in $(compgen -e | grep '^PLEAMAR_'); do unset "$v"; done
unset WAYLAND_DISPLAY DISPLAY CUA_INJECT_SOCKET AT_SPI_BUS_ADDRESS CALIMA_LOCK_REAL OPENBOT_DB
export HOME="$T/home" XDG_CONFIG_HOME="$T/config" XDG_DATA_HOME="$T/data" XDG_STATE_HOME="$T/state" XDG_CACHE_HOME="$T/cache" \
       XDG_RUNTIME_DIR="$T/runtime" PLEAMAR_HEADLESS_SCREENS=1 PLEAMAR_WM_AUTOSTART="$T/autostart" \
       PLEAMAR_HEADLESS_AT=999999 PLEAMAR_HEADLESS_PNG="$T/never.png" PLEAMAR_NO_PORTAL=1 SHELL=/bin/bash \
       PATH="$T/bin:$(dirname "$WM"):$PATH"
for v in HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR; do
  case "${!v}" in "$REPO/tmp/"*) ;; *) echo "not apart: $v=${!v}" >&2; exit 1;; esac
done
[ -z "${PLEAMAR_CONFIG:-}" ] || { echo "not apart: PLEAMAR_CONFIG=$PLEAMAR_CONFIG" >&2; exit 1; }
cat > "$T/inner.sh" <<INNER
set -u
W="$WM"; P="$PL"; R="$OUT/result.txt"; : > "\$R"
"\$W" headless "$(dirname "$WM")/../../examples/session.plm" > "$OUT/wm.log" 2>&1 &
wmpid=\$!
for i in \$(seq 1 80); do d=\$(grep -o 'programs connect at WAYLAND_DISPLAY=[^ )]*' "$OUT/wm.log" | head -1 | sed 's/.*=//'); [ -n "\$d" ] && break; sleep 0.25; done
export PLEAMAR_SOCKETS="$T/runtime/pleamar-\$d"
ok() { echo "OK    \$*" >> "\$R"; }; ko() { echo "FAIL  \$*" >> "\$R"; }
shot() { WAYLAND_DISPLAY=\$d grim -o HEADLESS-1 "$OUT/\$1.png" 2>> "$OUT/grim.log"; }
case "\$XDG_RUNTIME_DIR" in /run/user/*) ko "the real XDG_RUNTIME_DIR: stop"; exit 1;; esac
bpid=""; for i in \$(seq 1 80); do bpid=\$(pgrep -n -f "^$BIN $T/work\\\$"); [ -n "\$bpid" ] && break; sleep 0.25; done
[ -n "\$bpid" ] && ok "Bitácora started (pid \$bpid)" || { ko "no Bitácora"; kill \$wmpid; exit 1; }
B="bitacora-\$bpid"
g() { "\$P" --say "\$B" "get \$1" 2>/dev/null | tail -1; }
e() { "\$P" --say "\$B" "\$@" > /dev/null 2>&1; }
waitf() { for i in \$(seq 1 \${3:-50}); do [ "\$(g \$1)" = "\$2" ] && return 0; sleep 0.2; done; return 1; }
waitf term.0.alive 1 && ok "it answers to «\$B», and its first shell lives" || ko "«\$B» does not answer: term.0.alive=\$(g term.0.alive)"
sleep 1
p0=\$(g term.0.pid | cut -d. -f1)
"\$W" term list --json > "$OUT/list-0.json" 2>&1
python3 -c "import json,sys; d=json.load(open('$OUT/list-0.json')); l=[x for x in d['layers'] if x['id']==\$p0]; sys.exit(0 if l and int(l[0]['terminal'])==\$bpid else 1)" \
  && ok "term.0.pid (\$p0) is its shell's layer in pleamar-wm, whose terminal is Bitácora" || ko "term.0.pid \$p0 is no layer of Bitácora's"
shot 0-one
# The wheel: up goes back through the history, down comes back.
"\$W" term paste \$p0 "seq 1 300" > /dev/null 2>&1; "\$W" term keys \$p0 enter > /dev/null 2>&1; sleep 1
b0=\$(g term.0.back)
WAYLAND_DISPLAY=\$d "\$W" agent scroll \$bpid 400 400 up 3 > "$OUT/wheel-up.txt" 2>&1; sleep 0.6
b1=\$(g term.0.back)
WAYLAND_DISPLAY=\$d "\$W" agent scroll \$bpid 400 400 down 3 > /dev/null 2>&1; sleep 0.6
b2=\$(g term.0.back)
[ "\$b0" = 0 ] && [ "\$(echo "\$b1" | cut -d. -f1)" -gt 0 ] 2>/dev/null && [ "\$b2" = 0 ] && ok "the wheel up goes back through its history (\$b1 lines), down comes back to its end" || ko "wheel: back \$b0 → up \$b1 → down \$b2 · \$(head -2 "$OUT/wheel-up.txt")"
# An agent beside, wired to the pane.
e "emit agent_beside"
waitf s.1.ag 1 60 && ok "Ctrl+Shift+A: a pane beside with its agent, working (s.1.ag = 1)" || ko "the agent beside: s.1.ag=\$(g s.1.ag)"
p1=\$(g term.1.pid | cut -d. -f1)
"\$W" term list --json > "$OUT/list-1.json" 2>&1
python3 -c "import json,sys; d=json.load(open('$OUT/list-1.json')); sys.exit(0 if any(p['a']==\$p0 and p['b']==\$p1 for p in d['pairs']) else 1)" \
  && ok "the two panes are wired (term pair \$p0 \$p1)" || ko "no pair \$p0-\$p1: \$(cat "$OUT/list-1.json" | head -c 300)"
[ "\$(g pair.a)" = 0 ] && [ "\$(g pair.b)" = 1 ] && ok "the knot of the wire is drawn between them (pair.a 0, pair.b 1)" || ko "pair.a=\$(g pair.a) pair.b=\$(g pair.b)"
sleep 0.8; shot 1-agent-beside
# For the agent in it, the pane beside is a window wired to its own.
PLEAMAR_TERMINAL=\$p1 "\$W" link list > "$OUT/link-list.txt" 2>&1
grep -q "the pane beside yours" "$OUT/link-list.txt" && ok "link list, from the agent's pane: «\$(head -1 "$OUT/link-list.txt")»" || ko "link list: \$(cat "$OUT/link-list.txt")"
PLEAMAR_TERMINAL=\$p1 "\$W" link send pane "cat notes.txt" --enter > "$OUT/link-send.txt" 2>&1; sleep 1
"\$W" term read \$p0 20 > "$OUT/read-0.txt" 2>&1
grep -q "a line to select and send" "$OUT/read-0.txt" && ok "link send pane «cat notes.txt»: it ran in the pane beside" || ko "link send pane: \$(cat "$OUT/link-send.txt") / \$(tail -3 "$OUT/read-0.txt")"
PLEAMAR_TERMINAL=\$p1 "\$W" link read pane 5 > "$OUT/link-read.txt" 2>&1
grep -q "a line to select and send" "$OUT/link-read.txt" && ok "link read pane: the agent reads it" || ko "link read pane: \$(cat "$OUT/link-read.txt")"
waitf s.1.ag 2 60 && ok "the agent is ready again (s.1.ag = 2)" || ko "s.1.ag=\$(g s.1.ag)"
# A new tab, then the first tab brought to the front from outside (Calima's «View»).
e "emit new_tab"; sleep 1.5
t1=\$(g tab.cur)
e "emit show_layer \$p1"; sleep 0.5
[ "\$(g tab.cur)" != "\$t1" ] && [ "\$(g term.1.focus)" = 1 ] && ok "emit show_layer \$p1: its tab in front and its pane with the keys" || ko "show_layer: tab.cur=\$(g tab.cur) (was \$t1), term.1.focus=\$(g term.1.focus)"
# A companion's tab asked from outside (Calima's caravan): its own name, behind the tab in front.
tb=\$(g tab.cur)
e "text open.name probe2" "text open.folder $T/work" "text open.cmd echo tab-for-probe2" "fact open.front false" "emit open_named"
sleep 2.5
np=""; for i in \$(seq 1 20); do np=\$("\$W" term list --json | python3 -c "import json,sys; print(next((x['id'] for x in json.load(sys.stdin)['layers'] if x.get('name')=='probe2' and x.get('terminal')=='\$bpid'), ''))"); [ -n "\$np" ] && break; sleep 0.25; done
"\$W" term read "\$np" 5 > "$OUT/read-named.txt" 2>&1
[ -n "\$np" ] && [ "\$(g tab.cur)" = "\$tb" ] && grep -q "^tab-for-probe2" "$OUT/read-named.txt" && ok "emit open_named: a tab named probe2 behind the one in front, and its command ran" || ko "open_named: layer «\$np», tab.cur \$(g tab.cur) (was \$tb), \$(tail -2 "$OUT/read-named.txt")"
e "text open.name probe2" "fact open.front true" "emit open_named"; sleep 1
[ "\$(g tab.cur)" != "\$tb" ] && ok "asked again, its tab is brought forward, not opened twice" || ko "again: tab.cur=\$(g tab.cur)"
e "emit go_tab \$tb"; sleep 0.3
# «Send to…»: what is selected, to a companion.
"\$W" link post probe "hello" --from test > /dev/null 2>&1
"\$W" link mail probe --cancel 1 > /dev/null 2>&1
e "fact menu.s 0" "emit menu_do 2"; sleep 0.3
e "fact menu.s 0" "emit menu_do 10"
waitf send.on true 30 && ok "Send to…: the list of companions opens" || ko "send.on=\$(g send.on)"
sleep 0.8; shot 2-send-to
# (Only this session's companion may be there: a letter goes nowhere else.)
boxes=\$("\$W" link caravan --json | python3 -c "import json,sys; print(','.join(b['name'] for b in json.load(sys.stdin)['boxes']))")
if [ "\$boxes" = probe ]; then e "emit send_to 1"; sleep 1.5; else ko "other mailboxes than this test's (\$boxes): nothing sent"; fi
"\$W" link mail probe --json > "$OUT/mail.json" 2>&1
grep -q "a line to select and send" "$OUT/mail.json" && ok "the letter is in its mailbox, with what was selected" || ko "mail: \$(head -c 400 "$OUT/mail.json")"
# A program that takes the mouse selects by itself and copies (OSC 52): Send to… sends that, nothing selected.
"\$W" term paste "\$np" "printf '\\033]52;c;%s\\007' \$(printf 'copied by the program' | base64)" > /dev/null 2>&1
"\$W" term keys "\$np" enter > /dev/null 2>&1; sleep 1
ns=0; for i in \$(seq 0 11); do [ "\$(g term.\$i.pid | cut -d. -f1)" = "\$np" ] && ns=\$i; done
e "fact menu.s \$ns"; sleep 0.3; e "emit menu_do 10"
waitf send.on true 30 && e "emit send_to 1"; sleep 1.5
"\$W" link mail probe --json > "$OUT/mail2.json" 2>&1
grep -q "copied by the program" "$OUT/mail2.json" && ok "nothing selected, what the program copied (OSC 52) is what Send to… sends" || ko "copied: \$(head -c 300 "$OUT/mail2.json")"
# A companion's window: opened by pleamar-wm with Bitácora, named.
# (As Calima runs it: with the session's SHELL, its layer of terminals, and the real one beside it.)
lsh=\$(tr '\\0' '\\n' < /proc/\$bpid/environ | grep '^SHELL=' | cut -d= -f2-)
rsh=\$(tr '\\0' '\\n' < /proc/\$bpid/environ | grep '^PLEAMAR_REAL_SHELL=' | cut -d= -f2-)
WAYLAND_DISPLAY=\$d SHELL="\$lsh" PLEAMAR_REAL_SHELL="\$rsh" "\$W" link open --name probe --terminal "$T/bin/bitacora-c" --folder "$T/work" --quiet > "$OUT/open.txt" 2>&1
cpid=""; for i in \$(seq 1 40); do cpid=\$("\$W" term list --json | python3 -c "import json,sys; print(next((x['terminal'] for x in json.load(sys.stdin)['layers'] if x.get('name')=='probe'), ''))"); [ -n "\$cpid" ] && break; sleep 0.25; done
"\$W" term list --json > "$OUT/list-open.json" 2>&1
for q in \$(pgrep -f "$BIN"); do echo "\$q: \$(tr '\\0' ' ' < /proc/\$q/cmdline)"; tr '\\0' '\\n' < /proc/\$q/environ | grep -E '^(BITACORA_NAME|PLEAMAR_NAME)='; done > "$OUT/procs.txt" 2>&1
[ -n "\$cpid" ] && ok "link open --name probe --terminal bitacora: a window (\$(cat "$OUT/open.txt"))" || ko "link open: \$(cat "$OUT/open.txt")"
C="bitacora-\$cpid"
gc() { "\$P" --say "\$C" "get \$1" 2>/dev/null | tail -1; }
for i in \$(seq 1 40); do [ "\$(gc term.0.alive)" = 1 ] && break; sleep 0.2; done
"\$P" --say "\$C" "emit new_tab" > /dev/null 2>&1; sleep 1.5
c0=\$(gc term.0.pid | cut -d. -f1); c1=\$(gc term.1.pid | cut -d. -f1)
"\$W" term info \$c0 > "$OUT/info-c0.txt" 2>&1; "\$W" term info \$c1 > "$OUT/info-c1.txt" 2>&1
grep -q "^name probe" "$OUT/info-c0.txt" && ! grep -q "^name probe" "$OUT/info-c1.txt" && ok "only its first shell is the companion (a new tab is not)" || ko "names: \$(grep ^name "$OUT/info-c0.txt") / \$(grep ^name "$OUT/info-c1.txt")"
"\$P" --say "\$C" "emit go_tab 1" > /dev/null 2>&1
"\$W" term paste \$c0 claude > /dev/null 2>&1; "\$W" term keys \$c0 enter > /dev/null 2>&1
for i in \$(seq 1 40); do [ "\$(gc s.0.tone)" = 2 ] && break; sleep 0.25; done
[ "\$(gc s.0.tone)" = 2 ] && ok "its agent's tab takes the companion's colour and glyph (s.0.tone = 2)" || ko "s.0.tone=\$(gc s.0.tone) s.0.ag=\$(gc s.0.ag)"
sleep 1; shot 3-companion
# -e: a command instead of a shell.
touch "$T/go-e"; sleep 4
epid=\$(pgrep -n -f "^$BIN -e sh"); el=""
for l in \$("\$W" term list --json | python3 -c "import json,sys; print(' '.join(str(x['id']) for x in json.load(sys.stdin)['layers'] if x.get('terminal')=='\$epid'))"); do el=\$l; done
"\$W" term read "\$el" 10 > "$OUT/read-e.txt" 2>&1
grep -q "it ran: 42" "$OUT/read-e.txt" && ok "bitacora -e sh -c …: its first shell ran it" || ko "-e: \$(cat "$OUT/read-e.txt" | tail -3)"
kill \$wmpid 2>/dev/null; wait \$wmpid 2>/dev/null
INNER
dbus-run-session -- bash "$T/inner.sh" > "$OUT/inner.log" 2>&1
cat "$OUT/result.txt"
echo "(its folder: $T)"
