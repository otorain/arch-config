-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Copy mouse selection to PRIMARY so GoldenDict's Super+T (wl-paste -p) sees it
vim.keymap.set("x", "<LeftRelease>", '"*y', { desc = "Copy mouse selection to PRIMARY" })
