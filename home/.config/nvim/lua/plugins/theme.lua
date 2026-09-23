return {
  {
    "folke/tokyonight.nvim",
    opts = function(_, opts)
      local ok, matugen = pcall(require, "matugen_colors")

      if ok then
        opts.on_colors = function(colors)
          -- Dina bakgrunder
          colors.bg = matugen.bg
          colors.bg_dark = matugen.bg_dark
          colors.bg_float = matugen.bg_dark
          colors.bg_highlight = matugen.bg_highlight
          colors.bg_sidebar = matugen.bg_dark
          colors.bg_search = matugen.primary
          colors.fg = matugen.fg
          colors.fg_dark = matugen.fg_dark
          colors.border = matugen.border
          colors.border_highlight = matugen.primary

          -- Bakgrunden för bottenbaren
          colors.bg_statusline = matugen.bg_dark

          -- MAGIN: Här byter vi ut temats accentfärger mot din Matugen-färg!
          -- Detta gör att Lualine matchar i Normal, Insert och Visual-läge automatiskt.
          colors.blue = matugen.primary
          colors.cyan = matugen.primary
          colors.magenta = matugen.primary
          colors.purple = matugen.primary

          -- (Vi låter bli att ändra röd och gul, så att felmeddelanden
          -- i koden fortfarande syns tydligt!)
        end
      end
    end,
  },
}
