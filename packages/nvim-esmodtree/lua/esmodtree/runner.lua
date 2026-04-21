local util = require("esmodtree.util")

local M = {}

local NOTIFY_TITLE = "Esmodtree"
local notify_id = "esmodtree_runner"

--- Open a centered floating window with the given lines.
local function open_float(lines)
  -- Compute content dimensions
  local max_line_width = 0
  for _, line in ipairs(lines) do
    local len = vim.fn.strdisplaywidth(line)
    if len > max_line_width then
      max_line_width = len
    end
  end

  -- Cap at 80% of editor dimensions
  local max_width = math.floor(vim.o.columns * 0.8)
  local max_height = math.floor(vim.o.lines * 0.8)
  local width = math.min(max_line_width, max_width)
  local height = math.min(#lines, max_height)

  -- Ensure minimum size
  width = math.max(width, 1)
  height = math.max(height, 1)

  -- Create scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  -- Center the window
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    style = "minimal",
    title = NOTIFY_TITLE,
    title_pos = "center",
  })

  -- Set keymaps to close the float
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })
end

--- Run the CLI with the given subcommand for the current buffer.
function M.run(subcmd)
  local plugin_root = util.get_plugin_root()
  local bin = util.bin_path(plugin_root)

  -- Check binary exists
  if vim.fn.filereadable(bin) ~= 1 then
    vim.notify("Esmodtree: CLI not found. Run :Esmodtree install", vim.log.levels.ERROR)
    return
  end

  -- Get current buffer's file path
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == "" then
    vim.notify("Esmodtree: current buffer has no file", vim.log.levels.ERROR)
    return
  end

  -- Show spinner
  vim.notify("Esmodtree: running --" .. subcmd .. "...", vim.log.levels.INFO, { replace = notify_id })

  -- Execute CLI asynchronously
  vim.system({ bin, "--" .. subcmd, filepath, "--no-color" }, {}, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify("Esmodtree: " .. (result.stderr or "unknown error"), vim.log.levels.ERROR, { replace = notify_id })
        return
      end

      local stdout = result.stdout or ""
      if stdout == "" then
        vim.notify("Esmodtree: no output", vim.log.levels.WARN, { replace = notify_id })
        return
      end

      -- Split into lines, removing trailing empty line from final newline
      local lines = vim.split(stdout, "\n", { plain = true })
      if lines[#lines] == "" then
        table.remove(lines)
      end

      open_float(lines)
      vim.notify("", vim.log.levels.INFO, { replace = notify_id })
    end)
  end)
end

return M
