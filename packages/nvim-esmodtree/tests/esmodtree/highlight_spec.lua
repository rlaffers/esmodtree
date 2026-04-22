local h = require("helpers")

describe("esmodtree.highlight", function()
  local highlight

  before_each(function()
    package.loaded["esmodtree.highlight"] = nil
    highlight = require("esmodtree.highlight")
  end)

  describe("parse_line", function()
    it("parses a plain root line with marker", function()
      local parsed = highlight.parse_line("src/index.js [entry]")
      assert.is_not_nil(parsed)
      assert.equals(0, parsed.path_start)
      assert.equals(4, parsed.file_start) -- after "src/"
      assert.equals(12, parsed.path_end) -- length of "src/index.js"
      assert.equals(1, #parsed.markers)
      assert.equals("entry", parsed.markers[1].tag)
      assert.equals(13, parsed.markers[1].col_start)
      assert.equals(20, parsed.markers[1].col_end)
    end)

    it("parses a nested line with └── connector", function()
      -- "└── src/a.js" where "└──" is 3 3-byte chars = 9 bytes + space
      local line = "\xe2\x94\x94\xe2\x94\x80\xe2\x94\x80 src/a.js"
      local parsed = highlight.parse_line(line)
      assert.is_not_nil(parsed)
      assert.equals(10, parsed.path_start) -- skipped 9 prefix bytes + 1 space
      assert.equals(14, parsed.file_start) -- after "src/"
      assert.equals(18, parsed.path_end)
      assert.equals(0, #parsed.markers)
    end)

    it("parses multiple markers", function()
      local line = "src/b.js [barrel] [circular]"
      local parsed = highlight.parse_line(line)
      assert.is_not_nil(parsed)
      assert.equals(2, #parsed.markers)
      assert.equals("barrel", parsed.markers[1].tag)
      assert.equals("circular", parsed.markers[2].tag)
    end)

    it("handles path with no directory component", function()
      local parsed = highlight.parse_line("index.js")
      assert.is_not_nil(parsed)
      assert.equals(0, parsed.path_start)
      assert.equals(0, parsed.file_start)
      assert.equals(8, parsed.path_end)
    end)

    it("returns nil for whitespace-only line", function()
      assert.is_nil(highlight.parse_line("     "))
    end)

    it("returns nil for empty line", function()
      assert.is_nil(highlight.parse_line(""))
    end)
  end)

  describe("define_groups", function()
    it("registers all expected highlight groups", function()
      highlight.define_groups()
      local names = {
        "EsmodtreeDir",
        "EsmodtreeFile",
        "EsmodtreeMarkerEntry",
        "EsmodtreeMarkerPage",
        "EsmodtreeMarkerLayout",
        "EsmodtreeMarkerBarrel",
        "EsmodtreeMarkerDynamic",
        "EsmodtreeMarkerCircular",
      }
      for _, name in ipairs(names) do
        local hl = vim.api.nvim_get_hl(0, { name = name })
        assert.is_table(hl)
      end
    end)
  end)

  describe("highlight_line", function()
    local buf

    before_each(function()
      buf = vim.api.nvim_create_buf(false, true)
      highlight.define_groups()
    end)

    after_each(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end)

    it("creates extmarks for dir, basename, and marker", function()
      local line = "src/index.js [entry]"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
      highlight.highlight_line(buf, 0, line)

      local marks = vim.api.nvim_buf_get_extmarks(buf, highlight.ns, 0, -1, { details = true })
      assert.equals(3, #marks)

      -- Collect by hl_group
      local by_group = {}
      for _, m in ipairs(marks) do
        by_group[m[4].hl_group] = m
      end
      assert.is_not_nil(by_group.EsmodtreeDir)
      assert.is_not_nil(by_group.EsmodtreeFile)
      assert.is_not_nil(by_group.EsmodtreeMarkerEntry)
    end)

    it("skips unknown marker tags", function()
      local line = "src/a.js [bogus]"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
      highlight.highlight_line(buf, 0, line)

      local marks = vim.api.nvim_buf_get_extmarks(buf, highlight.ns, 0, -1, { details = true })
      -- dir + file only, no marker
      assert.equals(2, #marks)
    end)
  end)
end)

-- Suppress unused h warning when file is edited without using helpers
local _ = h
