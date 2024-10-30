-- debug.lua
--
-- Configuración para usar nvim-dap con CodeLLDB para depurar C/C++ y Python.

return {
  -- Plugin principal para depuración
  'mfussenegger/nvim-dap',

  -- Dependencias necesarias
  dependencies = {
    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- UI para nvim-dap
    'rcarriga/nvim-dap-ui',

    -- Gestor de paquetes para depuradores
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Depurador para Python
    'mfussenegger/nvim-dap-python',

    -- Depurador para Go, coméntalo si no lo usas
    'leoluz/nvim-dap-go',
  },

  -- Configuración de atajos de teclado para la depuración
  keys = function(_, keys)
    local dap = require 'dap'
    local dapui = require 'dapui'
    return {
      -- Atajos básicos de depuración
      { '<F5>', dap.continue, desc = 'Debug: Start/Continue' },
      { '<F11>', dap.step_into, desc = 'Debug: Step Into' },
      { '<F10>', dap.step_over, desc = 'Debug: Step Over' },
      { '<F12>', dap.step_out, desc = 'Debug: Step Out' },
      { '<leader>b', dap.toggle_breakpoint, desc = 'Debug: Toggle Breakpoint' },
      {
        '<leader>B',
        function()
          dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
        end,
        desc = 'Debug: Set Breakpoint',
      },
      -- Atajo para alternar la UI de depuración
      { '<leader>du', dapui.toggle, desc = 'Debug: Toggle UI' },
      -- Terminar sesión de debugging
      { '<leader>dx', dap.terminate, desc = 'Debug: Terminate Session' },
      unpack(keys),
    }
  end,

  -- Configuración del plugin
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    -- Configuración de mason-nvim-dap
    require('mason-nvim-dap').setup {
      -- Instalación automática de adaptadores de depuración
      automatic_installation = true,
      handlers = {},
      ensure_installed = {
        'codelldb', -- Adaptador de depuración para C/C++
        'debugpy', -- Adaptador de depuración para Python
      },
    }

    -- Configuración de Python DAP
    require('dap-python').setup '/usr/bin/python'

    -- Configuración del adaptador de Python
    dap.adapters.python = {
      type = 'executable',
      command = '/usr/bin/python',
      args = { '-m', 'debugpy.adapter' },
    }

    -- Configuraciones de lanzamiento para Python
    dap.configurations.python = {
      {
        -- Configuración básica
        type = 'python',
        request = 'launch',
        name = 'Launch file',
        program = '${file}',
        pythonPath = function()
          -- Intenta encontrar el entorno virtual primero
          local cwd = vim.fn.getcwd()
          if vim.fn.executable(cwd .. '/venv/bin/python') == 1 then
            return cwd .. '/venv/bin/python'
          elseif vim.fn.executable(cwd .. '/.venv/bin/python') == 1 then
            return cwd .. '/.venv/bin/python'
          else
            return '/usr/bin/python'
          end
        end,
      },
      {
        -- Configuración para debugging con argumentos
        type = 'python',
        request = 'launch',
        name = 'Launch with arguments',
        program = '${file}',
        args = function()
          local args_string = vim.fn.input 'Arguments: '
          return vim.split(args_string, ' ')
        end,
      },
      {
        -- Configuración para attach remoto
        type = 'python',
        request = 'attach',
        name = 'Attach remote',
        connect = function()
          local host = vim.fn.input 'Host [127.0.0.1]: '
          host = host ~= '' and host or '127.0.0.1'
          local port = tonumber(vim.fn.input 'Port [5678]: ') or 5678
          return { host = host, port = port }
        end,
      },
    }

    -- Configuración de la UI de depuración
    dapui.setup {
      layouts = {
        {
          elements = {
            { id = 'scopes', size = 0.25 },
            { id = 'breakpoints', size = 0.25 },
            { id = 'stacks', size = 0.25 },
            { id = 'watches', size = 0.25 },
          },
          position = 'left',
          size = 40,
        },
        {
          elements = {
            { id = 'repl', size = 0.5 },
            { id = 'console', size = 0.5 },
          },
          position = 'bottom',
          size = 10,
        },
      },
      controls = {
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '⏎',
          step_over = '⏭',
          step_out = '⏮',
          step_back = 'b',
          run_last = '▶▶',
          terminate = '⏹',
          disconnect = '⏏',
        },
      },
    }

    -- Vincular eventos de dap con la UI
    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Configuración de keymaps específicos para Python
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'python',
      callback = function()
        local opts = { buffer = true }
        -- Ejecutar archivo Python sin debugging
        vim.keymap.set('n', '<leader>pr', ':split | terminal python3 %<CR>', { buffer = true, desc = 'Run Python file (no debug)' })

        -- Test methods
        vim.keymap.set('n', '<leader>dm', function()
          require('dap-python').test_method()
        end, { buffer = true, desc = 'Debug Python: Test Method' })

        vim.keymap.set('n', '<leader>dc', function()
          require('dap-python').test_class()
        end, { buffer = true, desc = 'Debug Python: Test Class' })

        -- Debug selection
        vim.keymap.set('n', '<leader>ds', function()
          require('dap-python').debug_selection()
        end, { buffer = true, desc = 'Debug Selection' })
      end,
    })

    -- Configuración para C/C++ con CodeLLDB
    local mason_registry = require 'mason-registry'

    if mason_registry.is_installed 'codelldb' then
      local codelldb = mason_registry.get_package 'codelldb'
      local extension_path = codelldb:get_install_path() .. '/extension/'
      local adapter_path = extension_path .. 'adapter/codelldb'

      if vim.fn.filereadable(adapter_path) == 1 then
        dap.adapters.codelldb = {
          type = 'server',
          port = '${port}',
          executable = {
            command = adapter_path,
            args = { '--port', '${port}' },
          },
        }

        dap.configurations.c = {
          {
            name = 'Launch C Program',
            type = 'codelldb',
            request = 'launch',
            program = function()
              local file = vim.fn.expand '%:t:r'
              local cmd = 'gcc -g -o ' .. file .. ' ' .. vim.fn.expand '%'
              vim.cmd('split | terminal ' .. cmd)
              vim.cmd 'startinsert'
              return vim.fn.getcwd() .. '/' .. file
            end,
            cwd = '${workspaceFolder}',
            stopOnEntry = false,
            args = {},
            runInTerminal = false,
          },
        }

        dap.configurations.cpp = dap.configurations.c
      else
        vim.notify('CodeLLDB executable not found: ' .. adapter_path, vim.log.levels.ERROR)
      end
    end

    -- Configuración para Go
    require('dap-go').setup {
      delve = {
        detached = vim.fn.has 'win32' == 0,
      },
    }
  end,
}
