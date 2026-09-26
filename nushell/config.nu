# config.nu
#
# Installed by:
# version = "0.112.2"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings, 
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

# ── prompt ──────────────────────────────────────────────────────────────
#   user@host  <contracted cwd>  (branch*↑1↓2)          <duration> <clock>
# user@host is recoloured by environment:
#   purple = python venv, blue = nix shell, one of each when both.
# The indicator turns red and shows the exit code when a command fails.

# ~/projects/jiva -> ~/p/jiva  (fish's prompt_pwd)
def contract-pwd []: nothing -> string {
    let p = if ($env.PWD | str starts-with $env.HOME) {
        $env.PWD | str replace $env.HOME "~"
    } else { $env.PWD }
    let parts = ($p | split row "/")
    if ($parts | length) <= 1 { return $p }
    let head = $parts | drop 1 | each {|s|
        if ($s | is-empty) { $s
        } else if ($s | str starts-with ".") { $s | str substring 0..<2
        } else { $s | str substring 0..<1 }
    }
    $head | append ($parts | last) | str join "/"
}

# Branch, dirty flag and ahead/behind from a single `git status` call.
def git-info []: nothing -> string {
    let r = (do --ignore-errors {
        ^git status --porcelain=v2 --branch --untracked-files=normal | complete
    })
    if ($r == null) or ($r.exit_code != 0) { return "" }
    let lines = ($r.stdout | lines)

    let branch = $lines | where {|l| $l | str starts-with "# branch.head " }
        | get --optional 0 | default "" | str replace "# branch.head " ""
    if ($branch | is-empty) { return "" }

    let dirty = $lines | any {|l| not ($l | str starts-with "#") }
    let ab = $lines | where {|l| $l | str starts-with "# branch.ab " }
        | get --optional 0 | default ""

    let track = if ($ab | is-empty) { "" } else {
        let nums = ($ab | str replace "# branch.ab " "" | split row " ")
        let ahead = ($nums | get --optional 0 | default "+0" | str replace "+" "" | into int)
        let behind = ($nums | get --optional 1 | default "-0" | str replace "-" "" | into int)
        [ (if $ahead > 0 { $"↑($ahead)" } else { "" })
          (if $behind > 0 { $"↓($behind)" } else { "" }) ] | str join ""
    }

    let mark = if $dirty { $"(ansi yellow)*(ansi reset)" } else { "" }
    let tr = if ($track | is-empty) { "" } else { $"(ansi cyan)($track)(ansi reset)" }
    $" (ansi light_gray)\((ansi reset)(ansi purple)($branch)(ansi reset)($mark)($tr)(ansi light_gray)\)(ansi reset)"
}

def create_left_prompt []: nothing -> string {
    let in_venv = ($env.VIRTUAL_ENV? | is-not-empty)
    let in_nix = ($env.IN_NIX_SHELL? | is-not-empty) or ($env.__IN_NIX_SHELL_CMD? | is-not-empty)

    let user_color = if $in_venv { (ansi { fg: '#a855f7' })
        } else if $in_nix { (ansi { fg: '#2563eb' })
        } else { (ansi light_green) }
    let host_color = if $in_nix { (ansi { fg: '#2563eb' })
        } else if $in_venv { (ansi { fg: '#a855f7' })
        } else { (ansi reset) }

    let user = $"($user_color)(whoami | str trim)(ansi reset)"
    let host = $"($host_color)(hostname | str trim)(ansi reset)"
    let cwd = $"(ansi green_bold)(contract-pwd)(ansi reset)"
    $"($user)@($host) ($cwd)(git-info)"
}

# Right side: how long the last command took (if slow) and the time of day.
def create_right_prompt []: nothing -> string {
    let ms = ($env.CMD_DURATION_MS? | default "0" | into int)
    let dur = if $ms > 2000 {
        let secs = ($ms / 1000)
        let txt = if $secs >= 60 { $"(($secs // 60) | into int)m(($secs mod 60 | into int))s" } else { $"(($secs | math round --precision 1))s" }
        $"(ansi yellow)($txt)(ansi reset)  "
    } else { "" }
    let clock = $"(ansi dark_gray)(date now | format date '%H:%M')(ansi reset)"
    $"($dur)($clock)"
}

$env.PROMPT_COMMAND = {|| create_left_prompt }
$env.PROMPT_COMMAND_RIGHT = {|| create_right_prompt }
$env.PROMPT_INDICATOR = {||
    let code = ($env.LAST_EXIT_CODE? | default 0 | into int)
    if $code == 0 { $"(ansi light_gray)>(ansi reset) " } else { $"(ansi red_bold)[($code)]>(ansi reset) " }
}
$env.PROMPT_INDICATOR_VI_INSERT = ": "
$env.PROMPT_INDICATOR_VI_NORMAL = "> "
$env.PROMPT_MULTILINE_INDICATOR = $"(ansi dark_gray):::: (ansi reset)"

# ── aliases (ports of ~/.config/fish/functions/*.fish) ──────────────────
alias lsd = eza --icons always
alias geforcenow = env -u LANG -u LC_ALL flatpak run com.nvidia.geforcenow
def ns [] { nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history }

# ── virtualenv ──────────────────────────────────────────────────────────
# Activate ./.venv; `deactivate` (provided by the overlay) leaves it.
alias venv = overlay use .venv/bin/activate.nu

# ── nix ─────────────────────────────────────────────────────────────────
# `nix shell` exports no marker of its own (unlike nix-shell / nix develop,
# which set IN_NIX_SHELL), so tag it here for the prompt to pick up.
def --wrapped nix [...args] {
    let sub = ($args | where {|a| not ($a | str starts-with "-") } | get --optional 0)
    if $sub == "shell" {
        with-env { __IN_NIX_SHELL_CMD: "1" } { ^nix ...$args }
    } else {
        ^nix ...$args
    }
}

# ── keybindings ─────────────────────────────────────────────────────────
$env.config.keybindings = ($env.config.keybindings | append {
    name: venv_activate
    modifier: control_alt
    keycode: char_d
    mode: [emacs vi_insert vi_normal]
    event: { send: executehostcommand, cmd: "venv" }
})

# ── completions ─────────────────────────────────────────────────────────
# Nushell ships no completions for external commands, so borrow fish's
# (it has ~1000 of them, and its nix completion resolves real flake attrs
# like `nixpkgs#ripgrep`). Falls back to nix's own completion protocol for
# subcommands, which fish doesn't cover.

def fish-complete [spans: list<string>]: nothing -> list<string> {
    let line = $spans | each {|s| $s | str replace --all "'" "'\\''" } | str join " "
    ^fish --command $"complete --do-complete='($line)'"
    | lines
    | each {|l| $l | split row "\t" | first }
    | where {|c| $c | is-not-empty }
}

# NIX_GET_COMPLETIONS=<index of word to complete> nix <words...>
# Nix only answers for an empty trailing word, so we complete "" and filter.
def nix-complete [spans: list<string>]: nothing -> list<string> {
    let prefix = ($spans | last)
    let head = ($spans | drop 1 | skip 1)   # drop trailing word, skip "nix"
    let idx = ($head | length) + 1
    let out = (do --ignore-errors {
        with-env { NIX_GET_COMPLETIONS: ($idx | into string) } {
            ^nix ...$head "" | complete
        }
    })
    if ($out == null) or ($out.exit_code != 0) { return [] }
    let got = $out.stdout | lines | skip 1 | each {|l| $l | split row "\t" | first }
    # `nix shell` is live but absent from both `nix --help` and nix's own
    # completion list in 2.34, so add it back when completing a subcommand.
    let all = if $idx == 1 { $got | append "shell" | uniq | sort } else { $got }
    $all | where {|c| ($c | is-not-empty) and ($c | str starts-with $prefix) }
}

def external-completer [spans: list<string>]: nothing -> list<string> {
    let fish_res = (do --ignore-errors { fish-complete $spans } | default [])
    # For nix, merge both sources: fish knows flake attrs and flag docs,
    # nix's own protocol knows subcommands fish has no spec for.
    if ($spans | first) == "nix" {
        let nix_res = (do --ignore-errors { nix-complete $spans } | default [])
        return ($fish_res | append $nix_res | uniq | sort)
    }
    $fish_res
}

$env.config.completions.external = {
    enable: true
    max_results: 200
    completer: {|spans| external-completer $spans }
}
