local sysname = vim.uv.os_uname().sysname:lower()
local iswin = not not (sysname:find("windows") or sysname:find("mingw"))

-- Default to roslyn presumably installed by mason if found.
-- Fallback to the same default as `nvim-lspconfig`
local function get_default_cmd()
    local roslyn_bin = iswin and "roslyn.cmd" or "roslyn"
    local mason_bin = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", roslyn_bin)

    local exe = vim.fn.executable(mason_bin) == 1 and mason_bin
        or vim.fn.executable(roslyn_bin) == 1 and roslyn_bin
        or "Microsoft.CodeAnalysis.LanguageServer"

    return {
        exe,
        "--logLevel=Information",
        "--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.log.get_filename()),
        "--stdio",
    }
end

---@type vim.lsp.Config
return {
    name = "roslyn",
    filetypes = { "cs" },
    cmd = get_default_cmd(),
    cmd_env = {
        Configuration = vim.env.Configuration or "Debug",
    },
    capabilities = {
        textDocument = {
            -- HACK: Doesn't show any diagnostics if we do not set this to true
            diagnostic = {
                dynamicRegistration = true,
            },
        },
    },
    root_dir = function(bufnr, on_dir)
        local root_dir = vim.fs.root(bufnr, ".git")
        if root_dir == nil then
            -- NOTE: Cannot find the root of the project, fallback to the existing client's root_dir
            local existing_client = vim.lsp.get_clients({ name = "roslyn" })[1]
            if existing_client and existing_client.config.root_dir then
                on_dir(existing_client.config.root_dir)
                return
            end
        end

        on_dir(root_dir)
    end,
    on_init = {
        function(client)
            local solution = vim.g.roslyn_nvim_selected_solution
            if solution == nil or solution == "" then
                vim.notify("No solution selected, please run :Roslyn target", vim.log.levels.INFO, {
                    title = "roslyn.nvim",
                })
                return
            end

            client:notify("solution/open", {
                solution = vim.uri_from_fname(solution),
            })

            vim.notify("Initializing Roslyn for: " .. solution, vim.log.levels.INFO, { title = "roslyn.nvim" })
        end,
    },
    on_exit = {
        function()
            vim.notify("Roslyn server stopped", vim.log.levels.INFO, { title = "roslyn.nvim" })
        end,
    },
    commands = require("roslyn.lsp.commands"),
    handlers = require("roslyn.lsp.handlers"),
}
