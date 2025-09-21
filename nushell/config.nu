# config.nu
#
# Installed by:
# version = "0.107.0"
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


$env.PATH = $env.PATH | append "~/.cargo/bin/"

$env.PATH = $env.PATH | append "/usr/bin/"


$env.config.buffer_editor = "helix"

$env.config.completions.partial = true
$env.config.completions.use_ls_colors = true

$env.config.error_style = "fancy"


$env.config.completions.external.enable = true
$env.config.completions.external.max_results = 100



source ~/.cache/carapace/init.nu
