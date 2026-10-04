local M = {}

--- @class esmodtree.Reference
--- @field line integer 1-based line number
--- @field column integer 1-based byte column
--- @field kind "usage"|"import"

--- @class esmodtree.TreeNode
--- @field path string
--- @field circular boolean
--- @field markers string[]
--- @field children esmodtree.TreeNode[]
--- @field reference? esmodtree.Reference Where this file references the module on its path towards the queried file

--- Render a single node (and its descendants) into `lines` / `nodes`, using the
--- same layout as the CLI's text formatter so highlighting and folding keep working.
--- @param node esmodtree.TreeNode
--- @param prefix string
--- @param is_last boolean
--- @param is_root boolean
--- @param lines string[]
--- @param nodes esmodtree.TreeNode[]
local function walk(node, prefix, is_last, is_root, lines, nodes)
  local connector = ""
  if not is_root then
    connector = is_last and "└── " or "├── "
  end

  local tags = {}
  for _, marker in ipairs(node.markers or {}) do
    table.insert(tags, "[" .. marker .. "]")
  end
  if node.circular then
    table.insert(tags, "[circular]")
  end
  local suffix = #tags > 0 and (" " .. table.concat(tags, " ")) or ""

  table.insert(lines, prefix .. connector .. node.path .. suffix)
  table.insert(nodes, node)

  local child_prefix = ""
  if not is_root then
    child_prefix = prefix .. (is_last and "    " or "│   ")
  end
  local children = node.children or {}
  for i, child in ipairs(children) do
    walk(child, child_prefix, i == #children, false, lines, nodes)
  end
end

--- Render CLI `--json` output (a single tree or a forest) into display lines.
--- `nodes[i]` is the tree node that produced `lines[i]`.
--- @param decoded esmodtree.TreeNode|esmodtree.TreeNode[]
--- @return string[] lines
--- @return esmodtree.TreeNode[] nodes
function M.render(decoded)
  local lines = {}
  local nodes = {}
  local roots = vim.islist(decoded) and decoded or { decoded }
  for _, root in ipairs(roots) do
    walk(root, "", true, true, lines, nodes)
  end
  return lines, nodes
end

return M
