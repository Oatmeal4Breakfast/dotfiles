return {
  -- Configure conform.nvim for formatting with ONLY ruff
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "ruff_format" },
        html = { "prettier" },
        css = { "prettier" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        json = { "prettier" },
      },
    },
  },

  -- Configure nvim-lint for linting with ONLY ruff
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        python = { "ruff" },
      },
    },
  },

  -- Configure LSP servers
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Disable other Python LSPs
        pylsp = false,
        pyright = false,
        ruff_lsp = false,

        -- Enable ty (Astral's new type checker/LSP)
        ty = {},
      },
    },
  },
}
