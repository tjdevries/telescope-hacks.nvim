local Path = require('plenary.path')

local actions = require('telescope.actions')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')

local conf = require('telescope.config').values

local M = {}

M.params = function()
  return {
    textDocument = vim.lsp.util.make_text_document_params()
  }
end

M.command_handlers = {
  ["gopls.test"] = function(code_lens)
    --[[
    ||   value = {
    ||     command = {
    ||       arguments = {
    ||          "file:///home/tj/sourcegraph/lsif-go/internal/indexer/indexer_test.go",
    ||          { "TestIndexer" } 
    ||        },
    ||       command = "gopls.test",
    ||       title = "run test"
    ||     },
    ||     range = {
    ||       end = {
    ||         character = 0,
    ||         line = 9
    ||       },
    ||       start = {
    ||         character = 0,
    ||         line = 9
    ||       }
    ||     }
    ||   }
    --]]
    assert(code_lens.command, "We need this command, cause I haven't implemented resolve yet")

    local arguments = code_lens.command.arguments

    local file_path = vim.uri_to_fname(arguments[1])
    local package_path = Path:new(Path:new(file_path):parents()):absolute() .. '/...'
    -- if package_path then return end

    local test_matches = table.concat(arguments[2] or {}, "|")

    vim.cmd [[split]]
    vim.cmd(string.format(
      "term go test -run '%s' %s", 
      test_matches,
      package_path
    ))
  end,
}

M.handler = function(err, _, result)
  if err then
    print("Got an error...", err)
    return
  end

  if not result or vim.tbl_isempty(result) then
    print("No Code Lens")
    return
  end

  pickers.new({}, {
    prompt_title = 'LSP Code Lens',
    finder = finders.new_table {
      results = result,
      entry_maker = function(item)
        if not item.command then return end

        -- print("lnm, col", item.range.start.line, item.range.start.character)
        return {
          value = item,

          display = item.command.command,
          ordinal = item.command.command,

          filename = vim.fn.expand("%:p"),

          lnum = item.range.start.line + 1,
          col = item.range.start.character,
        }
      end,
    },
    previewer = conf.grep_previewer({}),
    sorter = conf.generic_sorter({}),
    attach_mappings = function()
      actions.goto_file_selection_edit:replace(function(prompt_bufnr)
        local entry = actions.get_selected_entry(prompt_bufnr)

        actions.close(prompt_bufnr)

        if M.command_handlers[entry.value.command.command] then
          M.command_handlers[entry.value.command.command](entry.value)
        else
          print("Best Guess")
          vim.lsp.buf.execute_command(entry.value.command)
        end
      end)

      return true
    end,
  }):find()
end

M.run = function()
  print("Executing code lens request...")
  vim.lsp.buf_request(0, 'textDocument/codeLens', M.params(), M.handler)
end

return M
