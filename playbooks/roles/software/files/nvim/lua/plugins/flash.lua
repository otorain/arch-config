return {
  "folke/flash.nvim",
  keys = {
    -- Disable flash's binding of s/S; restore default Vim behavior
    { "s", mode = { "n", "x", "o" }, false },
    { "S", mode = { "n", "x", "o" }, false },
  },
}
