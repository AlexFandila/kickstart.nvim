-- Configuración específica para Java
return {
  {
    'mfussenegger/nvim-jdtls',
    dependencies = {
      'folke/which-key.nvim',
      'neovim/nvim-lspconfig',
      'hrsh7th/cmp-nvim-lsp',
    },
    ft = 'java',
    config = function() -- Función para obtener el nombre del paquete desde el archivo actual
      local function get_package_name_from_file(bufnr)
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 10, false) -- Leer las primeras 10 líneas
        for _, line in ipairs(lines) do
          local package_name = line:match '^%s*package%s+([%w%.]+)%s*;'
          if package_name then
            return package_name
          end
        end
        return '' -- Retornar cadena vacía si no hay declaración de paquete
      end
      -- Funciones de utilidad
      local function find_maven_root()
        local current_dir = vim.fn.expand '%:p:h'
        while current_dir ~= '/' do
          if vim.fn.filereadable(current_dir .. '/pom.xml') == 1 then
            return current_dir
          end
          current_dir = vim.fn.fnamemodify(current_dir, ':h')
        end
        return nil
      end

      local function get_jdtls_paths()
        local jdtls_path = vim.fn.stdpath 'data' .. '/mason/packages/jdtls'
        local path_to_jar = vim.fn.glob(jdtls_path .. '/plugins/org.eclipse.equinox.launcher_*.jar')
        local lombok_path = jdtls_path .. '/lombok.jar'

        local config_path
        if vim.fn.has 'mac' == 1 then
          config_path = jdtls_path .. '/config_mac'
        elseif vim.fn.has 'unix' == 1 then
          config_path = jdtls_path .. '/config_linux'
        else
          config_path = jdtls_path .. '/config_win'
        end

        return {
          jdtls_path = jdtls_path,
          lombok_path = lombok_path,
          jar_path = path_to_jar,
          config_path = config_path,
        }
      end

      -- Obtener paths
      local paths = get_jdtls_paths()
      print('Lombok path: ' .. paths.lombok_path)

      -- Verificar que los archivos necesarios existen
      if vim.fn.filereadable(paths.jar_path) == 0 then
        vim.notify('JDTLS JAR not found. Please install jdtls with :Mason', vim.log.levels.ERROR)
        return
      end

      -- Descargar lombok si no existe
      if vim.fn.filereadable(paths.lombok_path) == 0 then
        vim.notify('Downloading lombok.jar...', vim.log.levels.INFO)
        local download_cmd = string.format('curl -L "https://projectlombok.org/downloads/lombok.jar" -o "%s"', paths.lombok_path)
        os.execute(download_cmd)
      end

      -- Configuración inicial
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)
      local jdtls = require 'jdtls'

      -- Configuración del workspace
      local root_markers = { '.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle' }
      local root_dir = require('jdtls.setup').find_root(root_markers)
      local project_name = vim.fn.fnamemodify(root_dir, ':p:h:t')
      local workspace_folder = vim.fn.stdpath 'data' .. '/site/java/workspace-root/' .. project_name

      -- Configuración de JDTLS
      local config = {
        cmd = {
          'java',
          '-Declipse.application=org.eclipse.jdt.ls.core.id1',
          '-Dosgi.bundles.defaultStartLevel=4',
          '-Declipse.product=org.eclipse.jdt.ls.core.product',
          '-Dlog.protocol=true',
          '-Dlog.level=ALL',
          '-javaagent:' .. paths.lombok_path,
          '--add-modules=ALL-SYSTEM',
          '--add-opens',
          'java.base/java.util=ALL-UNNAMED',
          '--add-opens',
          'java.base/java.lang=ALL-UNNAMED',
          '-jar',
          paths.jar_path,
          '-configuration',
          paths.config_path,
          '-data',
          workspace_folder,
        },
        root_dir = root_dir,
        capabilities = capabilities,
        settings = {
          java = {
            configuration = {
              updateBuildConfiguration = 'interactive',
              runtimes = {
                {
                  name = 'JavaSE-17',
                  path = '/usr/lib/jvm/java-17-openjdk/',
                  default = true,
                },
              },
            },
            eclipse = {
              downloadSources = true,
            },
            maven = {
              downloadSources = true,
            },
            implementationsCodeLens = {
              enabled = true,
            },
            referencesCodeLens = {
              enabled = true,
            },
            format = {
              enabled = true,
            },
            signatureHelp = {
              enabled = true,
            },
            contentProvider = {
              preferred = 'fernflower',
            },
            completion = {
              enabled = true,
              favoriteStaticMembers = {
                'org.junit.jupiter.api.Assertions.*',
                'org.junit.Assert.*',
                'org.junit.Assume.*',
                'org.mockito.Mockito.*',
              },
            },
            sources = {
              organizeImports = {
                starThreshold = 9999,
                staticStarThreshold = 9999,
              },
            },
            codeGeneration = {
              toString = {
                template = '${object.className}{${member.name()}=${member.value}, ${otherMembers}}',
              },
              useBlocks = true,
            },
            compiler = {
              processAnnotations = true,
            },
          },
        },
        init_options = {
          bundles = { paths.lombok_path },
          extendedClientCapabilities = {
            progressReportProvider = true,
            classFileContentsSupport = true,
            generateToStringPromptSupport = true,
            hashCodeEqualsPromptSupport = true,
            advancedExtractRefactoringSupport = true,
            advancedOrganizeImportsSupport = true,
            generateConstructorsPromptSupport = true,
            generateDelegateMethodsPromptSupport = true,
            moveRefactoringSupport = true,
            overrideMethodsPromptSupport = true,
            inferSelectionSupport = { 'extractMethod', 'extractVariable' },
            -- Añade la siguiente línea
            resolveAdditionalTextEditsSupport = true,
          },
        },
        on_attach = function(client, bufnr)
          vim.notify('JDTLS connected', vim.log.levels.INFO)

          -- Comandos de compilación
          vim.api.nvim_buf_create_user_command(bufnr, 'JdtCompile', function()
            jdtls.compile 'full'
          end, { desc = 'Compile Java project' })

          vim.api.nvim_buf_create_user_command(bufnr, 'MavenCompile', function()
            local maven_root = find_maven_root()
            if maven_root then
              vim.cmd 'split'
              local win = vim.api.nvim_get_current_win()
              local buf = vim.api.nvim_create_buf(false, true)
              vim.api.nvim_win_set_buf(win, buf)

              local cmd = string.format('cd "%s" && mvn clean compile', maven_root)
              vim.fn.termopen(cmd)
              vim.cmd 'startinsert'
            else
              vim.notify('No Maven project found', vim.log.levels.ERROR)
            end
          end, { desc = 'Compile Maven project' })

          -- Comando de ejecución
          vim.api.nvim_buf_create_user_command(bufnr, 'JavaRun', function()
            local maven_root = find_maven_root()
            local jdtls = require 'jdtls'

            -- Obtener el nombre del paquete desde el archivo
            local package_name = get_package_name_from_file(bufnr)
            -- Obtener el nombre de la clase
            local class_name = vim.fn.expand '%:t:r' -- Nombre del archivo sin extensión

            -- Construir el nombre completo de la clase principal
            local main_class = package_name ~= '' and (package_name .. '.' .. class_name) or class_name

            if maven_root then
              -- Es un proyecto Maven
              vim.cmd 'split'
              local win = vim.api.nvim_get_current_win()
              local buf = vim.api.nvim_create_buf(false, true)
              vim.api.nvim_win_set_buf(win, buf)

              local cmd = string.format('cd "%s" && mvn compile exec:java -Dexec.mainClass="%s"', maven_root, main_class)

              vim.fn.termopen(cmd)
              vim.cmd 'startinsert'
            else
              -- No es un proyecto Maven
              vim.cmd 'split'
              local win = vim.api.nvim_get_current_win()
              local buf = vim.api.nvim_create_buf(false, true)
              vim.api.nvim_win_set_buf(win, buf)

              local src_path = vim.fn.expand '%:p:h'
              local compile_cmd = string.format('javac "%s"', vim.fn.expand '%:p')
              local run_cmd = string.format('java -cp "%s" "%s"', src_path, main_class)

              local cmd = compile_cmd .. ' && ' .. run_cmd
              vim.fn.termopen(cmd)
              vim.cmd 'startinsert'
            end
          end, { desc = 'Run Java file' })

          -- Comando para ejecutar con argumentos
          vim.api.nvim_buf_create_user_command(bufnr, 'JavaRunArgs', function()
            vim.ui.input({ prompt = 'Enter arguments: ' }, function(args)
              if args == nil then
                return
              end

              local maven_root = find_maven_root()
              local jdtls = require 'jdtls'

              -- Obtener el nombre del paquete desde el archivo
              local package_name = get_package_name_from_file(bufnr)
              -- Obtener el nombre de la clase
              local class_name = vim.fn.expand '%:t:r' -- Nombre del archivo sin extensión

              -- Construir el nombre completo de la clase principal
              local main_class = package_name ~= '' and (package_name .. '.' .. class_name) or class_name

              if maven_root then
                vim.cmd 'split'
                local win = vim.api.nvim_get_current_win()
                local buf = vim.api.nvim_create_buf(false, true)
                vim.api.nvim_win_set_buf(win, buf)

                local cmd = string.format('cd "%s" && mvn compile exec:java -Dexec.mainClass="%s" -Dexec.args="%s"', maven_root, main_class, args)

                vim.fn.termopen(cmd)
                vim.cmd 'startinsert'
              else
                -- No es un proyecto Maven
                vim.cmd 'split'
                local win = vim.api.nvim_get_current_win()
                local buf = vim.api.nvim_create_buf(false, true)
                vim.api.nvim_win_set_buf(win, buf)

                local src_path = vim.fn.expand '%:p:h'
                local compile_cmd = string.format('javac "%s"', vim.fn.expand '%:p')
                local run_cmd = string.format('java -cp "%s" "%s" %s', src_path, main_class, args)

                local cmd = compile_cmd .. ' && ' .. run_cmd
                vim.fn.termopen(cmd)
                vim.cmd 'startinsert'
              end
            end)
          end, { desc = 'Run Java file with arguments' })

          -- Keymaps
          local opts = { buffer = bufnr, silent = true }
          -- Keymaps de refactoring
          vim.keymap.set('n', '<leader>jo', jdtls.organize_imports, opts)
          vim.keymap.set('n', '<leader>jv', jdtls.extract_variable, opts)
          vim.keymap.set('n', '<leader>jc', jdtls.extract_constant, opts)
          vim.keymap.set('n', '<leader>jm', jdtls.extract_method, opts)

          -- Keymaps de ejecución
          vim.keymap.set('n', '<leader>jr', ':JavaRun<CR>', vim.tbl_extend('force', opts, { desc = 'Run Java file' }))
          vim.keymap.set('n', '<leader>ja', ':JavaRunArgs<CR>', vim.tbl_extend('force', opts, { desc = 'Run Java with args' }))
          vim.keymap.set('n', '<leader>mc', ':MavenCompile<CR>', vim.tbl_extend('force', opts, { desc = 'Maven Compile' }))

          -- Autorun para archivos con main
          local function has_main_method()
            local content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            for _, line in ipairs(content) do
              if line:match 'public%s+static%s+void%s+main' then
                return true
              end
            end
            return false
          end

          if has_main_method() then
            local group = vim.api.nvim_create_augroup('JavaAutoRun' .. bufnr, { clear = true })
            vim.api.nvim_create_autocmd('BufWritePost', {
              group = group,
              buffer = bufnr,
              callback = function()
                vim.cmd 'JavaRun'
              end,
            })
          end

          -- Formato automático al guardar
          local format_group = vim.api.nvim_create_augroup('JavaLSP', { clear = true })
          vim.api.nvim_create_autocmd('BufWritePre', {
            group = format_group,
            buffer = bufnr,
            callback = function()
              vim.lsp.buf.format { bufnr = bufnr }
            end,
          })
        end,
      }

      -- Iniciar JDTLS
      jdtls.start_or_attach(config)
    end,
  },
  {
    'nvim-neo-tree/neo-tree.nvim',
    opts = function(_, opts)
      -- Función auxiliar para obtener el nombre del paquete basado en la ruta
      local function get_package_name(path)
        local java_root_pattern = '(.*[/\\]src[/\\].-[/\\]java[/\\])(.*)'
        local _, _, _, package_path = path:find(java_root_pattern)

        if package_path then
          return package_path:gsub('[/\\]', '.'):gsub('^%.', ''):gsub('^%s*(.-)%s*$', '%1')
        end
        return ''
      end

      -- Función para crear archivo Java con template
      local function create_java_file(path, template_type)
        local filename = vim.fn.input 'Nombre del archivo (sin .java): '
        if filename == '' then
          return
        end

        local full_path = path .. '/' .. filename .. '.java'
        local package_name = get_package_name(path)
        local file_content = ''

        -- Diferentes templates según el tipo
        if template_type == 'class' then
          file_content = string.format(
            [[
%s
/**
 * @author %s
 */
public class %s {

}]],
            package_name ~= '' and 'package ' .. package_name .. ';' or '',
            vim.fn.expand '$USER',
            filename
          )
        elseif template_type == 'main' then
          file_content = string.format(
            [[
%s
/**
 * @author %s
 */
public class %s {
    public static void main(String[] args) {
        
    }
}]],
            package_name ~= '' and 'package ' .. package_name .. ';' or '',
            vim.fn.expand '$USER',
            filename
          )
        elseif template_type == 'interface' then
          file_content = string.format(
            [[
%s
/**
 * @author %s
 */
public interface %s {

}]],
            package_name ~= '' and 'package ' .. package_name .. ';' or '',
            vim.fn.expand '$USER',
            filename
          )
        end

        -- Crear el archivo y escribir el contenido
        vim.fn.writefile(vim.split(file_content, '\n'), full_path)
        -- Abrir el archivo recién creado
        vim.cmd('edit ' .. full_path)
        -- Mover el cursor a una posición lógica según el template
        if template_type == 'main' then
          vim.cmd 'normal! 8G$'
        else
          vim.cmd 'normal! 6G$'
        end
        -- Refrescar neo-tree
        require('neo-tree.command').execute { action = 'refresh' }
      end

      -- Configurar los comandos de neo-tree
      opts.window = opts.window or {}
      opts.window.mappings = vim.tbl_deep_extend('force', opts.window.mappings or {}, {
        ['J'] = 'show_java_menu',
      })

      -- Añadir comandos personalizados
      opts.commands = vim.tbl_deep_extend('force', opts.commands or {}, {
        show_java_menu = function(state)
          local node = state.tree:get_node()
          if node.type == 'directory' then
            vim.ui.select({
              'Nueva Clase Java',
              'Nueva Clase con Main',
              'Nueva Interface',
            }, {
              prompt = 'Selecciona el tipo de archivo Java a crear:',
            }, function(choice)
              if choice == 'Nueva Clase Java' then
                create_java_file(node:get_id(), 'class')
              elseif choice == 'Nueva Clase con Main' then
                create_java_file(node:get_id(), 'main')
              elseif choice == 'Nueva Interface' then
                create_java_file(node:get_id(), 'interface')
              end
            end)
          else
            vim.notify('Por favor, selecciona una carpeta para crear el archivo Java', vim.log.levels.WARN)
          end
        end,
      })

      -- Manejar eventos
      opts.event_handlers = opts.event_handlers or {}
      table.insert(opts.event_handlers, {
        event = 'file_opened',
        handler = function(file_path)
          require('neo-tree.command').execute { action = 'close' }
        end,
      })

      return opts
    end,
  },
}
