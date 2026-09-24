-- Entry point. Load order matters: options first, then plugins, then
-- everything that depends on a plugin being present.
require("config.options")
require("config.keymaps")
require("config.plugins")

-- Both of these need plugins on disk, which isn't true until lazy.nvim has
-- finished its first install. Failing soft keeps :Lazy reachable.
pcall(require, "config.lsp")
pcall(require, "config.colorscheme")
