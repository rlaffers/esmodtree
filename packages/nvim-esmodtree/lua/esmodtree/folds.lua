local M = {}

-- Box-drawing byte sequences used by the CLI tree output.
-- U+2502 │ = E2 94 82, U+251C ├ = E2 94 9C, U+2514 └ = E2 94 94
-- U+2500 ─ = E2 94 80
local PIPE_SPACES = "\xe2\x94\x82   " -- "│   "
local FOUR_SPACES = "    "
local BRANCH_TEE = "\xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80 " -- "├── "
local BRANCH_END = "\xe2\x94\x94\xe2\x94\x80\xe2\x94\x80 " -- "└── "

--- Compute the fold depth for a single tree output line.
--- Walks the leading prefix counting 4-column indent units (`│   ` or
--- `    `). If the prefix ends with a branch marker (`├── ` / `└── `),
--- that adds one additional level. A bare root line returns 0.
--- @param line string
--- @return integer
local function level_of(line)
  local depth = 0
  local i = 1
  while true do
    if line:sub(i, i + 5) == PIPE_SPACES then
      depth = depth + 1
      i = i + 6
    elseif line:sub(i, i + 3) == FOUR_SPACES then
      depth = depth + 1
      i = i + 4
    else
      break
    end
  end
  if line:sub(i, i + 9) == BRANCH_TEE or line:sub(i, i + 9) == BRANCH_END then
    depth = depth + 1
  end
  return depth
end

-- Exposed for testing
M._level_of = level_of

--- Foldexpr callback. Reads the line at `lnum` (1-indexed) and returns
--- its fold level as a string, suitable for `:set foldexpr=`.
--- @param lnum integer
--- @return string
function M.level(lnum)
  local line = vim.fn.getline(lnum)
  return tostring(level_of(line))
end

--- Foldtext callback. Renders a collapsed fold as the fold's first line
--- followed by ` … (+N)` where N is the number of hidden lines.
--- @return string
function M.text()
  local first = vim.fn.getline(vim.v.foldstart)
  local hidden = vim.v.foldend - vim.v.foldstart
  return first .. " … (+" .. hidden .. ")"
end

return M
