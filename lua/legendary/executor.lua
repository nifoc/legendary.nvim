local M = {}

local function mode_from_table(modes, current_mode)
  if vim.tbl_contains(modes, current_mode) then
    return current_mode
  end

  for _, mode in pairs(modes) do
    if mode == 'n' then
      return mode
    end

    if mode == 'i' then
      return mode
    end
  end

  return nil
end

local function exec(item, mode, visual_selection)
  local utils = require('legendary.utils')
  local cmd = utils.get_definition(item, mode)
  local opts = utils.resolve_opts(item, mode)

  if mode == 'n' then -- normal mode
    vim.cmd('stopinsert')
  elseif mode == 'i' then -- insert mode
    vim.cmd('startinsert')
  elseif mode == 'v' then -- visual mode
    vim.cmd('normal! gv')
  end

  if type(cmd) == 'function' then
    cmd(visual_selection)
  else
    if item.unfinished then
      vim.cmd('stopinsert')
      -- % is escape character in gsub patterns
      -- strip param names between [] or {}
      cmd = cmd:gsub('{.*}$', ''):gsub('%[.*%]$', '')
      -- if unfinished command, remove trailing <CR>
      cmd = require('legendary.utils').strip_trailing_cr(cmd)
    elseif opts.expr then
      print('eval')
      cmd = item[1]
    elseif vim.startswith(item.kind, 'legendary.command') then
      vim.cmd(require('legendary.utils').strip_leading_cmd_char(cmd))
      return
    end

    cmd = vim.api.nvim_replace_termcodes(cmd, true, false, true)
    vim.api.nvim_feedkeys(cmd, 't', true)
  end
end

--- Attmept to execute the selected item
---@param item LegendaryItem
function M.try_execute(item, current_buf, visual_selection, current_mode, current_cursor_pos)
  if not item then
    return
  end

  local mode = item.mode or 'n'
  -- if there's a visual selection, execute in visual mode
  if visual_selection then
    mode = 'v'
  elseif type(mode) == 'table' then
    mode = mode_from_table(mode)
  end

  if mode == 'x' and visual_selection then
    mode = 'v'
  end

  if mode == nil or (mode ~= 'n' and mode ~= 'i' and mode ~= 'v') then
    require('legendary.utils').notify(
      'Executing keybinds is only supported for insert, normal, and visual mode bindings.',
      vim.log.levels.INFO
    )
    return
  end

  exec(item, mode, visual_selection)

  vim.schedule(function()
    if vim.api.nvim_get_current_buf() ~= current_buf then
      return
    end

    -- only if we're back in same buffer
    pcall(vim.api.nvim_win_set_cursor, 0, current_cursor_pos)
    if current_mode == 'n' then
      vim.cmd('stopinsert')
    elseif current_mode == 'i' then
      vim.cmd('startinsert')
    end
  end)
end

return M
