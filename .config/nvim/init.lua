-- Let Neovim auto-detect light/dark via OSC 11 terminal query
-- (works through SSH — Ghostty responds to the escape sequence)

-- Transparent background: use terminal bg, not colorscheme bg
local function clear_bg()
    vim.api.nvim_set_hl(0, "Normal", { bg = "NONE", ctermbg = "NONE" })
    vim.api.nvim_set_hl(0, "NonText", { bg = "NONE", ctermbg = "NONE" })
end
vim.api.nvim_create_autocmd("ColorScheme", { callback = clear_bg })
vim.api.nvim_create_autocmd("OptionSet", {
    pattern = "background",
    callback = function() vim.schedule(clear_bg) end,
})

-- Options
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.api.nvim_set_keymap("i", "jj", "<Esc>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-u>", "<C-u>zz", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-d>", "<C-d>zz", { noremap = true, silent = true })
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.shiftround = true
vim.opt.showcmd = true
vim.opt.autoread = true
vim.opt.autowrite = true
vim.wo.relativenumber = true
vim.opt.number = true
vim.opt.conceallevel = 1
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- Obsidian vault paths (from environment)
local lab_vault = os.getenv("LAB_VAULT")
local life_vault = os.getenv("LIFE_VAULT")

local obsidian_workspaces = {}
if lab_vault then
    table.insert(obsidian_workspaces, { name = "lab", path = lab_vault })
end
if life_vault then
    table.insert(obsidian_workspaces, { name = "life", path = life_vault })
end

-- Plugins
require("lazy").setup({
    -- Treesitter
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter").setup({})
            -- Install parsers if missing
            local wanted = { "markdown", "markdown_inline", "latex", "python", "rust",
                             "c", "cpp", "lua", "bash", "json", "yaml", "toml" }
            local installed = require("nvim-treesitter").get_installed()
            local installed_set = {}
            for _, lang in ipairs(installed) do installed_set[lang] = true end
            local missing = {}
            for _, lang in ipairs(wanted) do
                if not installed_set[lang] then table.insert(missing, lang) end
            end
            if #missing > 0 then
                vim.schedule(function()
                    require("nvim-treesitter").install(missing)
                end)
            end
        end,
    },
    -- Telescope
    {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.8",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find files" },
            { "<leader>fg", function() require("telescope.builtin").live_grep() end, desc = "Live grep" },
            { "<leader>fb", function() require("telescope.builtin").buffers() end, desc = "Buffers" },
            {
                "<leader>og",
                function()
                    local vault = life_vault or lab_vault
                    if vault then
                        require("telescope.builtin").live_grep({ search_dirs = { vault } })
                    else
                        vim.notify("No Obsidian vault configured", vim.log.levels.WARN)
                    end
                end,
                desc = "Grep Obsidian vault",
            },
        },
    },
    -- Obsidian
    {
        "epwalsh/obsidian.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        cond = function()
            return vim.loop.os_uname().sysname == "Darwin" and #obsidian_workspaces > 0
        end,
        opts = {
            workspaces = obsidian_workspaces,
            notes_subdir = "cache",
            new_notes_location = "notes_subdir",
            disable_frontmatter = true,
            completion = {
                nvim_cmp = true,
                min_chars = 2,
            },
            mappings = {
                ["gf"] = {
                    action = function()
                        return require("obsidian").util.gf_passthrough()
                    end,
                    opts = { noremap = false, expr = true, buffer = true },
                },
            },
        },
    },
    -- Completion engine (required for obsidian.nvim [[search)
    { "hrsh7th/nvim-cmp" },
    -- Lualine
    {
        "nvim-lualine/lualine.nvim",
        opts = { options = { theme = "auto" } },
    },
}, {
    install = { colorscheme = { "default" } },
    checker = { enabled = false },
})

-- Disable legacy markdown syntax to let Treesitter handle it
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
    pattern = "markdown",
    callback = function()
        vim.cmd("syntax off")
        vim.treesitter.start()
    end,
})

-- Transparent background (use terminal colors, not nvim's own bg)
vim.api.nvim_set_hl(0, "Normal", { bg = "NONE", ctermbg = "NONE" })
vim.api.nvim_set_hl(0, "NonText", { bg = "NONE", ctermbg = "NONE" })
