require("cscope_maps").setup({
  prefix = "<leader>c",
  skip_input_prompt = true,
  cscope = {
    picker = "telescope",
    skip_picker_for_single_result = true,
  }
})
