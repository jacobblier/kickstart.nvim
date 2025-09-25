local statusline = require 'mini.statusline'

-- Debounced statusline update mechanism
local statusline_cache = {}
local last_update_time = 0
local statusline_update_delay_ms = 100 -- Adjust this to change debounce timing

-- Calculate the appropriate path display based on window width
local function get_path_smart()
  local filepath = vim.fn.expand '%:.' or ''
  local shortened_path = filepath:gsub('([^/])[^/]+/', '%1/')
  local modified_status = vim.bo.modified and '[+]' or ''

  -- Calculate available space and choose appropriate path format
  local win_width = vim.api.nvim_win_get_width(0)
  local full_path_len = #filepath + #modified_status

  -- Use full path if it takes up less than 35% of window width, otherwise use shortened
  if full_path_len < (win_width * 0.35) then
    return string.format('%s%s', filepath, modified_status)
  else
    return string.format('%s%s', shortened_path, modified_status)
  end
end

-- Get diagnostics display string
local function get_diagnostics_display()
  local diag_counts = {}
  if vim.diagnostic and vim.diagnostic.count then
    local bufnr = vim.api.nvim_get_current_buf()
    diag_counts = vim.diagnostic.count(bufnr) or {}
  end

  local diag_parts = {}
  if diag_counts[vim.diagnostic.severity.ERROR] and diag_counts[vim.diagnostic.severity.ERROR] > 0 then
    table.insert(diag_parts, string.format('E:%d', diag_counts[vim.diagnostic.severity.ERROR]))
  end
  if diag_counts[vim.diagnostic.severity.WARN] and diag_counts[vim.diagnostic.severity.WARN] > 0 then
    table.insert(diag_parts, string.format('W:%d', diag_counts[vim.diagnostic.severity.WARN]))
  end
  if diag_counts[vim.diagnostic.severity.INFO] and diag_counts[vim.diagnostic.severity.INFO] > 0 then
    table.insert(diag_parts, string.format('I:%d', diag_counts[vim.diagnostic.severity.INFO]))
  end
  if diag_counts[vim.diagnostic.severity.HINT] and diag_counts[vim.diagnostic.severity.HINT] > 0 then
    table.insert(diag_parts, string.format('H:%d', diag_counts[vim.diagnostic.severity.HINT]))
  end

  return #diag_parts > 0 and table.concat(diag_parts, ' ') or ''
end

-- Get git branch information
local function get_git_branch()
  local git_cmd_branch = 'git -C ' .. vim.fn.expand '%:p:h' .. ' branch --show-current'
  local branch_name = vim.fn.system(git_cmd_branch):gsub('\n', '')
  if vim.v.shell_error ~= 0 then
    return 'Not in a git repo'
  end
  return (branch_name and branch_name ~= '') and string.format(' %s', branch_name) or ''
end

-- Get git commit hash
local function get_git_hash()
  local git_cmd_hash = 'git -C ' .. vim.fn.expand '%:p:h' .. ' log --format=%h -1'
  local hash = vim.fn.system(git_cmd_hash):gsub('\n', '')
  if vim.v.shell_error ~= 0 then
    return ''
  end
  return (hash and hash ~= '') and string.format(' %s', hash) or ''
end

-- Get LSP syntax or filetype
local function get_syntax_display()
  local lsp_clients = vim.lsp.get_clients { bufnr = vim.api.nvim_get_current_buf() }
  local lsp_syntax = next(lsp_clients) and vim.bo.filetype or vim.bo.syntax
  return lsp_syntax and string.format('%s', lsp_syntax) or ''
end

-- Get Python environment information
local function get_python_env()
  if vim.bo.filetype ~= 'python' then
    return ''
  end

  local venv = os.getenv 'VIRTUAL_ENV'
  local conda_env = os.getenv 'CONDA_DEFAULT_ENV'

  if venv then
    local env_name = venv:match '([^/]+)$' or venv
    return string.format('(%s)', env_name)
  elseif conda_env then
    return string.format('(%s)', conda_env)
  end

  return ''
end

-- Get position information and highlight group
local function get_position_info()
  local line = vim.fn.line '.'
  local column = vim.fn.col '.'
  local percent = math.floor((line / vim.fn.line '$') * 100)
  local status_position = string.format('%d:%d %d%%%%', line, column, percent)

  -- Determine highlight group based on mode
  local mode = vim.api.nvim_get_mode().mode
  local position_status_hl
  if mode == 'i' then
    position_status_hl = 'MiniStatusLinePositionInsert'
  elseif mode == 'n' then
    position_status_hl = 'MiniStatusLinePositionNormal'
  elseif mode == 'v' then
    position_status_hl = 'MiniStatusLinePositionVisual'
  elseif mode == 'V' then
    position_status_hl = 'MiniStatusLinePositionVisualLine'
  elseif mode == 'c' then
    position_status_hl = 'MiniStatusLinePositionCommand'
  else
    position_status_hl = 'MiniStatusLinePositionNormal'
  end

  return status_position, position_status_hl
end

-- Filter out nil values from table
local function filter_nil(tbl)
  local result = {}
  for _, item in ipairs(tbl) do
    if item ~= nil then
      table.insert(result, item)
    end
  end
  return result
end

local function get_statusline_content()
  local status_path = get_path_smart()
  local diag_display = get_diagnostics_display()
  local git_branch = get_git_branch()
  local git_hash = get_git_hash()
  local syntax_display = get_syntax_display()
  local python_env = get_python_env()
  local status_position, position_status_hl = get_position_info()

  -- Build the actual display line
  return statusline.combine_groups(filter_nil {
    (status_path and status_path ~= '') and { hl = 'MiniStatuslineFilename', strings = { status_path } },
    (status_path and status_path ~= '' and diag_display and diag_display ~= '') and { hl = 'MiniStatuslineSeparator', strings = { '|' } },
    (diag_display and diag_display ~= '') and { hl = 'MiniStatuslineDiagnostics', strings = { diag_display } },
    ((status_path and status_path ~= '') or (diag_display and diag_display ~= ''))
      and (git_branch and git_branch ~= '')
      and { hl = 'MiniStatuslineSeparator', strings = { '|' } },
    '%<', -- Truncate following groups if there is not enough space
    (git_branch and git_branch ~= '') and { hl = 'MiniStatuslineGitBranch', strings = { git_branch } },
    (git_hash and git_hash ~= '') and { hl = 'MiniStatuslineGitHash', strings = { git_hash } },
    '%=', -- Right align following groups
    (python_env and python_env ~= '') and { hl = 'MiniStatuslinePythonEnv', strings = { python_env } },
    (syntax_display and syntax_display ~= '') and { hl = 'MiniStatuslineSyntax', strings = { syntax_display } },
    { hl = position_status_hl, strings = { status_position or '' } },
  })
end

local function update_statusline_cache()
  local bufnr = vim.api.nvim_get_current_buf()
  statusline_cache[bufnr] = get_statusline_content()
end

-- set use_icons to true if you have a Nerd Font
statusline.setup {
  use_icons = vim.g.have_nerd_font,
  content = {
    active = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local current_time = vim.loop.hrtime() / 1000000 -- Convert to milliseconds

      -- Check if enough time has passed since last update
      if not statusline_cache[bufnr] or (current_time - (last_update_time or 0)) > statusline_update_delay_ms then
        update_statusline_cache()
        last_update_time = current_time
      end

      return statusline_cache[bufnr] or get_statusline_content()
    end,
    inactive = function()
      local filepath = vim.fn.expand '%:.' or ''
      local modified_status = vim.bo.modified and '[+]' or ''
      return string.format(' %s%s ', filepath, modified_status)
    end,
  },
}

-- NOTE: It would be better to use the statusline.section_* functions since this is the recommended way to customize
-- the statusline. However, asking Claude Sonnet 4 to do so on 2025-04-22 did not give very good and optimized results,
-- so I decided to stay with the custom functions (even though they were created by the same LLM). I leave the code
-- below as an example of how to use the statusline.section_* functions.

-- -- You can configure sections in the statusline by overriding their
-- -- default behavior. For example, here we set the section for
-- -- cursor location to LINE:COLUMN
-- ---@diagnostic disable-next-line: duplicate-set-field
-- statusline.section_location = function()
--   return '%2l:%-2v'
-- end
--
-- -- Example: Customize the filename section to show relative path
-- ---@diagnostic disable-next-line: duplicate-set-field
-- statusline.section_filename = function()
--   local path = vim.fn.expand '%:~:.'
--   if path == '' then
--     return '[No Name]'
--   end
--   return vim.bo.modified and path .. ' [+]' or path
-- end
--
-- -- Example: Customize diagnostics to show only errors and warnings
-- ---@diagnostic disable-next-line: duplicate-set-field
-- statusline.section_diagnostics = function()
--   local diag_counts = vim.diagnostic.count(0)
--   local parts = {}
--   if diag_counts[vim.diagnostic.severity.ERROR] then
--     table.insert(parts, 'E:' .. diag_counts[vim.diagnostic.severity.ERROR])
--   end
--   if diag_counts[vim.diagnostic.severity.WARN] then
--     table.insert(parts, 'W:' .. diag_counts[vim.diagnostic.severity.WARN])
--   end
--   return #parts > 0 and table.concat(parts, ' ') or ''
-- end
