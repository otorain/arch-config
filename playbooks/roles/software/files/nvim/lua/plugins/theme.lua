-- Theme: catppuccin mocha (matches the rest of the system)
return {
  -- Override LazyVim's default colorscheme (tokyonight moon)
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },

  -- catppuccin ships with LazyVim's default spec (lazy = true);
  -- pin the flavour explicitly so the default can't silently change
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "mocha",
    },
  },
}
