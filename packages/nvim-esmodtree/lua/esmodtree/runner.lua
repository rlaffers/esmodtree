local util = require("esmodtree.util")
local highlight = require("esmodtree.highlight")

local M = {}

--- @alias esmodtree.Display "float"|"loclist"

local NOTIFY_TITLE = "Esmodtree"
local notify_id = "esmodtree_runner"

--- Open a floating window near the cursor with the given lines.
--- The float is placed below the cursor when it is in the upper half of the
--- window, and above it otherwise. The left border aligns with the cursor column.
--- @param lines string[]
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

  -- Determine cursor position within the visible window
  local win_line = vim.fn.winline() -- 1-indexed row within window
  local win_height = vim.api.nvim_win_get_height(0)
  local show_below = win_line <= math.floor(win_height / 2)

  -- Clip height to available space in the chosen direction.
  -- screen_row is the 1-indexed row of the cursor on the entire screen.
  local screen_row = vim.fn.screenrow()
  if show_below then
    -- Space below: from line after cursor to bottom, minus 1 for cmdline and 2 for borders
    local space_below = vim.o.lines - screen_row - 3
    height = math.max(math.min(height, space_below), 1)
  else
    -- Space above: from top to line before cursor, minus 2 for borders
    local space_above = screen_row - 3
    height = math.max(math.min(height, space_above), 1)
  end

  -- Vertical offset (relative = "cursor"; border drawn outside content area)
  -- Below: top border on line below cursor → row = 2
  -- Above: bottom border on line above cursor → row = -(height + 1)
  local row = show_below and 1 or -(height + 2)

  -- Horizontal offset: left border at cursor column → col = 1
  -- Shift left if the float would overflow the right edge of the screen.
  local screen_col = vim.fn.screencol() -- 1-indexed cursor screen column
  local float_visual_width = width + 2 -- content + left/right borders
  local col = 1
  local overflow = (screen_col - 1) + float_visual_width - vim.o.columns
  if overflow > 0 then
    col = col - overflow
    -- Clamp so the left border doesn't go off the left edge.
    -- With relative="cursor", absolute screen col of left border = (screen_col - 1) + (col - 1).
    -- We need that >= 0.
    local min_col = -(screen_col - 2)
    col = math.max(col, min_col)
  end

  -- Create scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local config = require("esmodtree").config or {}
  if config.use_colors ~= false then
    highlight.define_groups()
    highlight.highlight_buffer(buf, lines)
  end

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
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

--- Extract a file path from a tree output line by stripping leading
--- box-drawing characters (U+2500 ─, U+2502 │, U+251C ├, U+2514 └,
--- U+2550 ═) and whitespace, then returning the first non-space token.
--- Returns "" when no path can be extracted.
--- @param line string
--- @return string
local function extract_path(line)
  -- Box-drawing chars used by the CLI are 3-byte UTF-8 sequences in the
  -- range \xe2\x94\x80 – \xe2\x95\x90. Strip those bytes plus ASCII spaces.
  local stripped = line:gsub("[\xe2][\x94\x95][\x80-\xbf]", ""):gsub("^ +", "")
  local token = stripped:match("(%S+)")
  return token or ""
end

-- Expose for testing
M._extract_path = extract_path

--- Render loclist entries as the raw tree text only, hiding the default
--- "filename|lnum col col| text" prefix so tree-drawing characters align.
--- @param info table Neovim quickfix text function info
--- @return string[]
local function render_loclist(info)
  local entries = vim.fn.getloclist(info.winid, { id = info.id, items = 1 }).items
  local out = {}
  for i = info.start_idx, info.end_idx do
    table.insert(out, entries[i].text)
  end
  return out
end

-- Expose for testing
M._render_loclist = render_loclist

--- Tracks whether the BufWinEnter autocmd for loclist highlighting has been
--- installed in this Neovim session. Idempotent guard -- the augroup itself
--- uses `clear = true`, but re-creating on every :lopen is unnecessary work.
--- @type boolean
local loclist_augroup_installed = false

--- Install a BufWinEnter autocmd that colorizes the quickfix buffer whenever
--- a location list with our title is shown. Idempotent.
local function ensure_loclist_highlighter()
  if loclist_augroup_installed then
    return
  end
  loclist_augroup_installed = true

  local group = vim.api.nvim_create_augroup("EsmodtreeLoclist", { clear = true })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(args)
      local buf = args.buf
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      if vim.bo[buf].buftype ~= "quickfix" then
        return
      end

      local win = vim.api.nvim_get_current_win()
      local info = vim.fn.getloclist(win, { title = 1 })
      -- Clear any stale marks from a prior Esmodtree list
      vim.api.nvim_buf_clear_namespace(buf, highlight.ns, 0, -1)

      if not info or info.title ~= NOTIFY_TITLE then
        -- Not our list anymore; restore qf defaults so other plugins' lists
        -- render with normal qf syntax when they reuse this buffer.
        vim.bo[buf].syntax = "on"
        return
      end

      -- Disable qf's builtin syntax on our buffer. qfFileName (linked to
      -- Directory) matches our whole line because quickfixtextfunc strips
      -- the `file|lnum col|` prefix -- leaving no `|` to stop the match.
      -- Its blue fg would bleed through our extmarks (which set only bold).
      vim.bo[buf].syntax = "off"

      local config = require("esmodtree").config or {}
      if config.use_colors == false then
        return
      end

      highlight.define_groups()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      highlight.highlight_buffer(buf, lines)
    end,
  })
end

-- Expose for testing
M._ensure_loclist_highlighter = ensure_loclist_highlighter

--- Open a location list populated with the given tree output lines.
--- Each entry preserves the original line as display text. Selecting an
--- entry jumps to the extracted file at line 1, column 1.
--- @param lines string[]
local function open_loclist(lines)
  local items = {}
  for _, line in ipairs(lines) do
    local path = extract_path(line)
    table.insert(items, {
      filename = path,
      lnum = 1,
      col = 1,
      text = line,
    })
  end

  ensure_loclist_highlighter()

  vim.fn.setloclist(0, {}, " ", {
    title = NOTIFY_TITLE,
    items = items,
    quickfixtextfunc = render_loclist,
  })
  vim.cmd("lopen")
end

--- Run the CLI with the given subcommand for the current buffer.
--- When `symbol` is provided, appends `--symbol <name>` to the CLI command.
--- `display` is "float" (default) or "loclist".
--- @param subcmd string
--- @param symbol? string
--- @param display? esmodtree.Display
function M.run(subcmd, symbol, display)
  display = display or "float"
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

  -- Build command
  local cmd = { bin, "--" .. subcmd, filepath, "--no-color" }
  if symbol then
    table.insert(cmd, "--symbol")
    table.insert(cmd, symbol)
  end

  -- Show spinner
  local label = "--" .. subcmd
  if symbol then
    label = label .. " (" .. symbol .. ")"
  end
  vim.notify("Esmodtree: running " .. label .. "...", vim.log.levels.INFO, { replace = notify_id })

  -- Execute CLI asynchronously
  vim.system(cmd, {}, function(result)
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

      if display == "loclist" then
        open_loclist(lines)
      else
        open_float(lines)
      end
      vim.notify("", vim.log.levels.INFO, { replace = notify_id })
    end)
  end)
end

return M
