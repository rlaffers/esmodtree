local M = {}

--- Namespace used for all extmark highlights applied by this plugin.
--- @type integer
M.ns = vim.api.nvim_create_namespace("esmodtree")

--- @class esmodtree.Marker
--- @field tag string The marker tag name (e.g. "entry", "barrel")
--- @field col_start integer 0-indexed byte column of `[`
--- @field col_end integer 0-indexed byte column one past `]`

--- @class esmodtree.ParsedLine
--- @field path_start integer 0-indexed byte column where the file path starts
--- @field file_start integer 0-indexed byte column where the basename starts
--- @field path_end integer 0-indexed byte column one past the end of the path
--- @field markers esmodtree.Marker[]

--- Default highlight group links. A nil `link` means set attrs directly.
--- @type { [string]: { link?: string, bold?: boolean } }
local DEFAULTS = {
  EsmodtreeDir = { link = "Comment" },
  EsmodtreeFile = { bold = true },
  EsmodtreeMarkerEntry = { link = "DiagnosticOk" },
  EsmodtreeMarkerPage = { link = "Statement" },
  EsmodtreeMarkerLayout = { link = "Function" },
  EsmodtreeMarkerBarrel = { link = "DiagnosticHint" },
  EsmodtreeMarkerDynamic = { link = "DiagnosticWarn" },
  EsmodtreeMarkerCircular = { link = "DiagnosticError" },
}

--- Register the plugin's highlight groups with `default = true` so user or
--- colorscheme overrides win. Idempotent.
function M.define_groups()
  for name, spec in pairs(DEFAULTS) do
    local opts = { default = true }
    if spec.link then
      opts.link = spec.link
    end
    if spec.bold then
      opts.bold = true
    end
    vim.api.nvim_set_hl(0, name, opts)
  end
end

--- Map a marker tag name to its highlight group. Returns nil for unknown tags.
--- @param tag string
--- @return string?
local function marker_group(tag)
  if #tag == 0 then
    return nil
  end
  local name = "EsmodtreeMarker" .. tag:sub(1, 1):upper() .. tag:sub(2):lower()
  if DEFAULTS[name] then
    return name
  end
  return nil
end

--- Parse a rendered tree line into byte ranges for highlighting.
--- Skips the leading run of tree-drawing characters (U+2500–U+2550) and
--- spaces, then identifies the path token, its basename offset, and any
--- `[tag]` markers following it.
--- Returns nil when no path token is present.
--- @param line string
--- @return esmodtree.ParsedLine?
function M.parse_line(line)
  local i = 1
  local len = #line
  while i <= len do
    local b = line:byte(i)
    if b == 0x20 then
      i = i + 1
    elseif b == 0xe2 and i + 2 <= len then
      local b2 = line:byte(i + 1)
      if b2 == 0x94 or b2 == 0x95 then
        -- 3-byte box-drawing sequence
        i = i + 3
      else
        break
      end
    else
      break
    end
  end

  local path_start = i - 1
  while i <= len and line:byte(i) ~= 0x20 do
    i = i + 1
  end
  local path_end = i - 1

  if path_end <= path_start then
    return nil
  end

  -- Locate last '/' within the path bytes
  local file_start = path_start
  for j = path_end, path_start + 1, -1 do
    if line:byte(j) == 0x2f then
      file_start = j
      break
    end
  end

  -- Collect [tag] markers after the path
  local markers = {}
  local search_from = path_end + 1
  while true do
    local s, e, tag = line:find("%[([%w_]+)%]", search_from + 1)
    if not s then
      break
    end
    table.insert(markers, { tag = tag, col_start = s - 1, col_end = e })
    search_from = e
  end

  return {
    path_start = path_start,
    file_start = file_start,
    path_end = path_end,
    markers = markers,
  }
end

--- Apply highlights for a single line in the given buffer.
--- @param buf integer
--- @param lnum integer 0-indexed line number
--- @param line string
function M.highlight_line(buf, lnum, line)
  local parsed = M.parse_line(line)
  if not parsed then
    return
  end

  -- Directory prefix (everything up to and including the last '/')
  if parsed.file_start > parsed.path_start then
    vim.api.nvim_buf_set_extmark(buf, M.ns, lnum, parsed.path_start, {
      end_col = parsed.file_start,
      hl_group = "EsmodtreeDir",
    })
  end

  -- Basename
  if parsed.path_end > parsed.file_start then
    vim.api.nvim_buf_set_extmark(buf, M.ns, lnum, parsed.file_start, {
      end_col = parsed.path_end,
      hl_group = "EsmodtreeFile",
    })
  end

  -- Markers
  for _, m in ipairs(parsed.markers) do
    local group = marker_group(m.tag)
    if group then
      vim.api.nvim_buf_set_extmark(buf, M.ns, lnum, m.col_start, {
        end_col = m.col_end,
        hl_group = group,
      })
    end
  end
end

--- Apply highlights for all lines in the buffer.
--- @param buf integer
--- @param lines string[]
function M.highlight_buffer(buf, lines)
  for i, line in ipairs(lines) do
    M.highlight_line(buf, i - 1, line)
  end
end

return M
