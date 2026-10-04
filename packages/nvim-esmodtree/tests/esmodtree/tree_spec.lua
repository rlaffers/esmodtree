local function node(path, children, extra)
  local n = { path = path, circular = false, markers = {}, children = children or {} }
  for k, v in pairs(extra or {}) do
    n[k] = v
  end
  return n
end

describe("esmodtree.tree", function()
  local tree

  before_each(function()
    package.loaded["esmodtree.tree"] = nil
    tree = require("esmodtree.tree")
  end)

  it("renders a lone root without a connector", function()
    local lines, nodes = tree.render(node("a.ts"))
    assert.same({ "a.ts" }, lines)
    assert.equals(1, #nodes)
  end)

  -- Mirrors the output of formatTree in packages/cli/src/output/tree.ts
  it("matches the CLI text formatter for a nested tree", function()
    local root = node("src/index.ts", {
      node("src/a.ts", {
        node("src/a1.ts"),
        node("src/a2.ts"),
      }, { markers = { "barrel" } }),
      node("src/b.ts", {
        node("src/b1.ts", {}, { circular = true }),
      }, { markers = { "entry", "dynamic" } }),
    })

    local lines = tree.render(root)

    assert.same({
      "src/index.ts",
      "├── src/a.ts [barrel]",
      "│   ├── src/a1.ts",
      "│   └── src/a2.ts",
      "└── src/b.ts [entry] [dynamic]",
      "    └── src/b1.ts [circular]",
    }, lines)
  end)

  it("renders a forest with each tree starting at the left edge", function()
    local lines = tree.render({
      node("a.ts", { node("t.ts") }),
      node("b.ts", { node("t.ts") }),
    })

    assert.same({ "a.ts", "└── t.ts", "b.ts", "└── t.ts" }, lines)
  end)

  it("keeps nodes aligned one-to-one with lines", function()
    local a = node("a.ts", {}, { reference = { line = 1, column = 2, kind = "usage" } })
    local lines, nodes = tree.render(node("t.ts", { a }))

    assert.equals(#lines, #nodes)
    assert.equals("a.ts", nodes[2].path)
    assert.same({ line = 1, column = 2, kind = "usage" }, nodes[2].reference)
  end)

  it("returns no lines for an empty forest", function()
    local lines = tree.render({})
    assert.same({}, lines)
  end)
end)
