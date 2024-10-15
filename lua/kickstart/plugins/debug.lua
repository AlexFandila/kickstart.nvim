-- debug.lua
--
-- Configuración para usar nvim-dap con CodeLLDB para depurar C/C++.
-- Además, incluye soporte para Go si es necesario.

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

    -- Depurador para Go, coméntalo si no lo usas
    'leoluz/nvim-dap-go',
  },

  -- Configuración de atajos de teclado para la depuración
  keys = function(_, keys)
    local dap = require 'dap'
    local dapui = require 'dapui'
    return {
      -- Atajos básicos de depuración
      { '<leader>dc', dap.continue, desc = 'Debug: Start/Continue' },
      { '<leader>di', dap.step_into, desc = 'Debug: Step Into' },
      { '<leader>do', dap.step_over, desc = 'Debug: Step Over' },
      { '<leader>dt', dap.step_out, desc = 'Debug: Step Out' },
      { '<leader>b', dap.toggle_breakpoint, desc = 'Debug: Toggle Breakpoint' },
      {
        '<leader>B',
        function()
          dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
        end,
        desc = 'Debug: Set Breakpoint',
      },
      -- Atajo para alternar la UI de depuración
      { '<F7>', dapui.toggle, desc = 'Debug: Toggle UI' },
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

      -- Handlers predeterminados, puedes personalizarlos si es necesario
      handlers = {},

      -- Lista de adaptadores a instalar
      ensure_installed = {
        'codelldb', -- Adaptador de depuración para C/C++
        -- 'delve', -- Descomenta si necesitas depuración para Go
        -- 'lldb',  -- Remueve si no usas lldb estándar
      },
    }

    -- Configuración de la UI de depuración
    dapui.setup {
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
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

    -- Configuración para C/C++ con CodeLLDB
    local mason_registry = require 'mason-registry'

    if mason_registry.is_installed 'codelldb' then
      local codelldb = mason_registry.get_package 'codelldb'
      local extension_path = codelldb:get_install_path() .. '/extension/codelldb'
      local adapter_path = extension_path .. '/adapter/codelldb'

      -- Asegúrate de que el ejecutable existe
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
              -- Obtener el nombre del archivo sin extensión
              local file = vim.fn.expand '%:t:r'
              -- Comando para compilar el programa con gcc
              local cmd = 'gcc -g -o ' .. file .. ' ' .. vim.fn.expand '%'
              -- Ejecutar el comando de compilación en una terminal dividida
              vim.cmd('split | terminal ' .. cmd)
              -- Cambiar al modo insert en la terminal para ver la salida
              vim.cmd 'startinsert'
              -- Retornar la ruta completa del ejecutable
              return vim.fn.getcwd() .. '/' .. file
            end,
            cwd = '${workspaceFolder}',
            stopOnEntry = false,
            args = {}, -- Puedes añadir argumentos aquí si tu programa los necesita
            runInTerminal = false,
          },
        }

        -- Corregir el typo en la configuración de C++
        dap.configurations.cpp = dap.configurations.c
        vim.notify('El ejecutable de CodeLLDB no se encuentra en la ruta esperada: ' .. adapter_path, vim.log.levels.ERROR)
      end
    end

    -- Configuración para Go (si es necesario)
    require('dap-go').setup {
      delve = {
        -- En Windows, delve debe ejecutarse adjunto o se bloquea
        detached = vim.fn.has 'win32' == 0,
      },
    }
  end,
}
