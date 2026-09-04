return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          win = {
            -- Don't close the explorer on <Esc>; use q or <leader>e instead
            input = { keys = { ["<Esc>"] = false } },
            list = { keys = { ["<Esc>"] = false } },
            preview = { keys = { ["<Esc>"] = false } },
          },
        },
      },
    },
  },
}
