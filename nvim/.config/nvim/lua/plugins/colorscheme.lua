return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "frappe",
      background = {
        dark = "frappe",
      },
      integrations = {
        blink_cmp = true,
        gitsigns = true,
        lsp_trouble = true,
        mason = true,
        native_lsp = { enabled = true },
        noice = true,
        snacks = true,
        treesitter = true,
        which_key = true,
      },
    },
  },

  -- Tell LazyVim to activate it globally on startup
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-frappe",
    },
  },
}
