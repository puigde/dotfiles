-- Read theme from state file
local function get_theme()
    local f = io.open(os.getenv("HOME") .. "/.local/state/theme", "r")
    if f then
        local theme = f:read("*l")
        f:close()
        if theme == "dark" then return "dark" end
    end
    return "light"  -- default (cream + light both work as "light")
end
vim.o.background = get_theme()

-- Transparent background
vim.cmd([[
    augroup TransparentBG
        autocmd!
        autocmd ColorScheme * highlight Normal guibg=NONE ctermbg=NONE
        autocmd ColorScheme * highlight NonText guibg=NONE ctermbg=NONE
    augroup END
]])

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

-- Plugins
require("lazy").setup({
    -- Treesitter
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        opts = {
            ensure_installed = { "markdown", "markdown_inline", "latex", "python", "rust",
                                 "c", "cpp", "lua", "bash", "json", "yaml", "toml" },
            highlight = { enable = true },
        },
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
        },
    },
    -- Lualine
    {
        "nvim-lualine/lualine.nvim",
        opts = { options = { theme = "auto" } },
    },
}, {
    install = { colorscheme = { "habamax" } },
    checker = { enabled = false },
})
