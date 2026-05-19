return {
  "rgroli/other.nvim",
  event = "BufRead",
  cmd = { "Other" },

  config = function()
    local enabled_languages = {
      "java",
    }

    local all_mappings = {}

    for _, lang in ipairs(enabled_languages) do
      local success, lang_mod = pcall(require, "other-langs." .. lang)
      if success then
        if lang_mod.mappings then
          for _, mapping in ipairs(lang_mod.mappings) do
            table.insert(all_mappings, mapping)
          end
        end
        if lang_mod.setup_autocmds then lang_mod.setup_autocmds() end
      else
        vim.notify("Fehler beim Laden von other-langs." .. lang .. ": " .. tostring(lang_mod), vim.log.levels.ERROR)
      end
    end

    require("other-nvim").setup {
      mappings = all_mappings,
    }
  end,

  init = function() vim.keymap.set("n", "<leader>jt", "<cmd>Other<CR>", { desc = "Toggle Main/Test File" }) end,
}
