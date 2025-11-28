-- Core Neovim options and settings
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- General settings
vim.opt.number = true
vim.opt.fillchars:append { eob = " " }
vim.opt.cursorline = false
vim.opt.laststatus = 0
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.clipboard = "unnamedplus"
vim.opt.updatetime = 200
vim.opt.termguicolors = true
vim.opt.encoding = "utf-8"
vim.opt.pumheight = 12
vim.opt.pumwidth = 50
vim.o.pumwidth = 45   -- minimum width, prevents it from shrinking too much
vim.o.winborder = 'rounded'

-- Python host program
vim.g.python3_host_prog = '/home/suraj/demo/venv/bin/python3.13'
