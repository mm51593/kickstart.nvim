local harpoon = require("harpoon")
harpoon:setup()

local conf = require("telescope.config").values
local function toggle_telescope(harpoon_files)
  local file_paths = {}
  for _, item in ipairs(harpoon_files.items) do
    table.insert(file_paths, item.value)
  end

  require("telescope.pickers").new({}, {
    prompt_title = "Harpoon",
      finder = require("telescope.finders").new_table({
      results = file_paths,
      attach_mappings = function(prompt_buffer_number, map)
        map("i", "<C-d>", function()
            local state = require("telescope.actions.state")
            local seelected_entry = state.get_selected_entry()
            local current_picker = state.get_current_picker(prompt_buffer_number)

            harpoon:list():removeAt(seelected_entry.index)
            current_picker:refresh(make_finder())
          end
        )
        return true
      end
    }),

    previewer = conf.file_previewer({}),
    sorter = conf.generic_sorter({}),
  }):find()
end

vim.keymap.set("n", "<C-e>", function() toggle_telescope(harpoon:list()) end,
  { desc = "Open harpoon window" })
vim.keymap.set("n", "<leader>h", function() harpoon:list():add() end)

vim.keymap.set("n", "<C-h>1", function() harpoon:list():select(1) end)
vim.keymap.set("n", "<C-h>2", function() harpoon:list():select(2) end)
vim.keymap.set("n", "<C-h>3", function() harpoon:list():select(3) end)
vim.keymap.set("n", "<C-h>4", function() harpoon:list():select(4) end)
vim.keymap.set("n", "<C-h>5", function() harpoon:list():select(4) end)
vim.keymap.set("n", "<C-h>6", function() harpoon:list():select(4) end)
vim.keymap.set("n", "<C-h>7", function() harpoon:list():select(4) end)
vim.keymap.set("n", "<C-h>8", function() harpoon:list():select(4) end)
vim.keymap.set("n", "<C-h>9", function() harpoon:list():select(4) end)
