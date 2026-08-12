return {
  -- Load the standard community-favorite gruvbox plugin
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      -- Force dark theme variant explicitly
      vim.o.background = "dark"

      -- Optional configuration settings
      require("gruvbox").setup({
        terminal_colors = true, -- add neovim terminal colors
        undercurl = true,
        underline = true,
        bold = true,
        italic = {
          strings = true,
          emphasis = true,
          comments = true,
          operators = false,
          folds = true,
        },
        strikethrough = true,
        invert_selection = false,
        invert_signs = false,
        invert_tabline = false,
        invert_intend_guides = false,
        inverse = true, -- invert background for search, diffs, statuslines and errors
        contrast = "hard", -- Options: "", "soft", "medium", "hard"
        dim_inactive = false,
        transparent_mode = false,
      })
    end,
  },

  -- Tell LazyVim to activate it globally on startup
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
