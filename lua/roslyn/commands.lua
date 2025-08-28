-- Huge credits to mrcjkb
-- https://github.com/mrcjkb/rustaceanvim/blob/2fa45427c01ded4d3ecca72e357f8a60fd8e46d4/lua/rustaceanvim/commands/init.lua
local M = {}

local cmd_name = "Roslyn"

---@class RoslynSubcommandTable
---@field impl fun(args: string[], opts: vim.api.keyset.user_command) The command implementation
---@field complete? fun(subcmd_arg_lead: string): string[] Command completions callback, taking the lead of the subcommand's arguments

---@type RoslynSubcommandTable[]
local subcommand_tbl = {
    restart = {
        impl = function()
            if vim.g.roslyn_nvim_selected_solution == nil then
                vim.notify("No solution selected, please run :Roslyn target or :Roslyn start", vim.log.levels.WARN, {
                    title = "roslyn.nvim",
                })
                return
            end

            vim.lsp.enable("roslyn", false)
            vim.lsp.enable("roslyn", true)
        end,
    },
    stop = {
        impl = function()
            vim.g.roslyn_nvim_selected_solution = nil
            vim.lsp.enable("roslyn", false)

            -- get all clients and stop them
            local force = vim.loop.os_uname().sysname == "Windows_NT"
            local clients = vim.lsp.get_clients({ name = "roslyn" })
            for _, client in pairs(clients) do
                client:stop(force)
            end
        end,
    },
    solution = {
        impl = function()
            if vim.g.roslyn_nvim_selected_solution ~= nil then
                vim.notify(
                    "A solution is already selected, please run :Roslyn restart or :Roslyn stop first",
                    vim.log.levels.WARN,
                    { title = "roslyn.nvim" }
                )
                return
            end

            local bufnr = vim.api.nvim_get_current_buf()
            local utils = require("roslyn.sln.utils")
            local solutions = utils.find_solutions_broad(bufnr)

            -- If we have more than one solution, immediately ask to pick one
            if #solutions > 1 then
                vim.ui.select(solutions or {}, { prompt = "Select target solution: " }, function(solutionFile)
                    if not solutionFile then
                        return
                    end

                    vim.lsp.enable("roslyn", false)
                    vim.g.roslyn_nvim_selected_solution = solutionFile
                    vim.lsp.enable("roslyn", true)
                end)
                return
            end

            if #solutions == 1 then
                vim.lsp.enable("roslyn", false)
                vim.g.roslyn_nvim_selected_solution = solutions[1]
                vim.lsp.enable("roslyn", true)
                return
            end
        end,
    },
}

---@param opts table
---@see vim.api.nvim_create_user_command
local function roslyn(opts)
    local fargs = opts.fargs
    local cmd = fargs[1]
    local args = #fargs > 1 and vim.list_slice(fargs, 2, #fargs) or {}
    local subcommand = subcommand_tbl[cmd]
    if type(subcommand) == "table" and type(subcommand.impl) == "function" then
        subcommand.impl(args, opts)
        return
    end

    vim.notify(cmd_name .. ": Unknown subcommand: " .. cmd, vim.log.levels.ERROR, { title = "roslyn.nvim" })
end

function M.create_roslyn_commands()
    vim.api.nvim_create_user_command(cmd_name, roslyn, {
        nargs = "+",
        range = true,
        desc = "Interacts with Roslyn",
        complete = function(arg_lead, cmdline, _)
            local all_commands = vim.tbl_keys(subcommand_tbl)

            local subcmd, subcmd_arg_lead = cmdline:match("^" .. cmd_name .. "[!]*%s(%S+)%s(.*)$")
            if subcmd and subcmd_arg_lead and subcommand_tbl[subcmd] and subcommand_tbl[subcmd].complete then
                return subcommand_tbl[subcmd].complete(subcmd_arg_lead)
            end

            if cmdline:match("^" .. cmd_name .. "[!]*%s+%w*$") then
                return vim.tbl_filter(function(command)
                    return command:find(arg_lead) ~= nil
                end, all_commands)
            end
        end,
    })
end

return M
