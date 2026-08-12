return {
  "folke/flash.nvim",
  keys = {
    -- 禁用 flash 对 s/S 的占用，恢复 Vim 默认行为
    { "s", mode = { "n", "x", "o" }, false },
    { "S", mode = { "n", "x", "o" }, false },
  },
}
