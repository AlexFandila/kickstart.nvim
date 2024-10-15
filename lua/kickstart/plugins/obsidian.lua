return {
  {
    -- Obsidian
    'epwalsh/obsidian.nvim',
    version = '*', -- recommended, use latest release instead of latest commit
    lazy = true,
    ft = 'markdown',
    -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
    -- event = {
    --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
    --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
    --   -- refer to `:h file-pattern` for more examples
    --   "BufReadPre path/to/my-vault/*.md",
    --   "BufNewFile path/to/my-vault/*.md",
    -- },
    dependencies = {
      -- Required.
      'nvim-lua/plenary.nvim',

      -- see below for full list of optional dependencies 👇
    },
    opts = {
      templates = {
        folder = '~/life/obsidian/',
      },
      workspaces = {
        {
          name = 'personal',
          path = '~/life',
        },
      },
      {
        name = 'apartados',
        path = '~/life/apartados',
      },
      {
        name = 'diarios',
        path = '~/life',
      },
      mappings = {
        -- Overrides 'gf' mapping to work on markdown/wiki links within your vault.
        ['gf'] = {
          action = function()
            return require('obsidian').util.gf_passthrough()
          end,
        },
        -- Toggle check-boxes
        ['<leader>ch'] = {
          action = function()
            return require('obsidian').util.toggle_checkbox()
          end,
          opts = { buffer = true },
        },
        -- Smart action depending on context, either follow link or toggle checkbox.
        ['<cr>'] = {
          action = function()
            return require('obsidian').util.smart_action()
          end,
          opts = { buffer = true, expr = true },
        },
      },
      -- see below for full list of options 👇
    },
  },
  {
    -- PRETTY MARKDOWN
    'MEANDERINGPROGRAMMER/RENDER-MARKDOWN.NVIM',
    ENABLED = FALSE,
    OPTS = {},
    DEPENDENCIES = { 'NVIM-TREESITTER/NVIM-TREESITTER', 'ECHASNOVSKI/MINI.NVIM' },
  },
}
