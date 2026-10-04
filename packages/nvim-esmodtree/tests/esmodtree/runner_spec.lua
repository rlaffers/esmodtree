local h = require("helpers")

--- Stub vim.fn.filereadable to return controlled values for matching path patterns.
local function stub_filereadable(map)
  return h.stub_filereadable(map)
end

--- Stub vim.api.nvim_buf_get_name to return a controlled path.
local function stub_buf_name(path)
  local original = vim.api.nvim_buf_get_name
  vim.api.nvim_buf_get_name = function()
    return path
  end
  return function()
    vim.api.nvim_buf_get_name = original
  end
end

--- Find a floating window among open windows. Returns win id or nil.
local function find_float_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative and config.relative ~= "" then
      return win
    end
  end
  return nil
end

--- Close any open floating windows (cleanup helper).
local function close_floats()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative and config.relative ~= "" then
      vim.api.nvim_win_close(win, true)
    end
  end
end

--- Build a CLI JSON tree node.
local function node(path, children, extra)
  local n = { path = path, circular = false, markers = {}, children = children or {} }
  for k, v in pairs(extra or {}) do
    n[k] = v
  end
  return n
end

--- Encode a tree (or forest) the way the CLI's --json does.
local function json(root)
  return vim.json.encode(root)
end

describe("esmodtree.runner", function()
  local runner
  local cleanups

  before_each(function()
    cleanups = {}
    package.loaded["esmodtree"] = nil
    package.loaded["esmodtree.runner"] = nil
    package.loaded["esmodtree.util"] = nil
    package.loaded["esmodtree.highlight"] = nil
    runner = require("esmodtree.runner")
  end)

  after_each(function()
    h.drain()
    h.drain()
    close_floats()
    for _, fn in ipairs(cleanups) do
      fn()
    end
  end)

  describe("run", function()
    it("notifies error when CLI binary is not installed", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 0 }))

      runner.run("down")

      assert.equals(1, #notifications)
      assert.is_truthy(notifications[1].msg:find("install"))
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
    end)

    it("executes esmodtree --down <path> --json for down subcommand", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local system_calls, restore_system = h.stub_system()
      table.insert(cleanups, restore_system)

      runner.run("down")

      assert.equals(1, #system_calls)
      local cmd = system_calls[1].cmd
      assert.is_truthy(cmd[1]:find("esmodtree"))
      assert.equals("--down", cmd[2])
      assert.equals("/project/src/index.ts", cmd[3])
      assert.equals("--json", cmd[4])
    end)

    it("executes esmodtree --updown <path> --json for updown subcommand", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local system_calls, restore_system = h.stub_system()
      table.insert(cleanups, restore_system)

      runner.run("updown")

      assert.equals(1, #system_calls)
      local cmd = system_calls[1].cmd
      assert.is_truthy(cmd[1]:find("esmodtree"))
      assert.equals("--updown", cmd[2])
      assert.equals("/project/src/index.ts", cmd[3])
      assert.equals("--json", cmd[4])
    end)

    it("notifies error on CLI failure with stderr content", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 1, stdout = "", stderr = "Error: file not found" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down")
      h.drain()

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find("Error: file not found"))
      assert.equals(vim.log.levels.ERROR, last.level)

      -- No float should be opened
      assert.is_nil(find_float_win())
    end)

    it("notifies warning on empty output and does not open float", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = "", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down")
      h.drain()

      local last = notifications[#notifications]
      assert.equals(vim.log.levels.WARN, last.level)

      -- No float should be opened
      assert.is_nil(find_float_win())
    end)

    it("opens a floating window on success with output", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node("src/index.ts", { node("src/foo.ts"), node("src/bar.ts") })), stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down")
      h.drain()

      local win = find_float_win()
      assert.is_not_nil(win)
    end)

    it("float buffer contains the rendered tree lines", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node("src/a.ts", { node("src/b.ts"), node("src/c.ts") })), stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down")
      h.drain()

      local win = find_float_win()
      assert.is_not_nil(win)
      local buf = vim.api.nvim_win_get_buf(win)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.equals("src/a.ts", lines[1])
      assert.equals("├── src/b.ts", lines[2])
      assert.equals("└── src/c.ts", lines[3])
    end)

    it("float buffer is a scratch buffer (nofile, not modifiable)", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node("output.ts")), stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down")
      h.drain()

      local win = find_float_win()
      assert.is_not_nil(win)
      local buf = vim.api.nvim_win_get_buf(win)
      assert.equals("nofile", vim.bo[buf].buftype)
      assert.is_false(vim.bo[buf].modifiable)
    end)

    it("float has a rounded border with centered title", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node("output.ts")), stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down")
      h.drain()

      local win = find_float_win()
      assert.is_not_nil(win)
      local config = vim.api.nvim_win_get_config(win)
      -- Neovim returns border as a table of characters for named styles
      local rounded_chars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
      assert.same(rounded_chars, config.border)
      assert.equals(" 🔎 Dependency tree ⇩ ", config.title[1][1])
      assert.equals("center", config.title_pos)
    end)

    it("float is capped at 80% of editor dimensions", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      -- Create output wider and taller than any reasonable editor
      local long_line = string.rep("x", 500)
      local many_lines = {}
      for i = 1, 200 do
        many_lines[i] = node(long_line)
      end
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node(long_line, many_lines)), stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down")
      h.drain()

      local win = find_float_win()
      assert.is_not_nil(win)
      local config = vim.api.nvim_win_get_config(win)
      local max_width = math.floor(vim.o.columns * 0.8)
      local max_height = math.floor(vim.o.lines * 0.8)
      assert.is_true(config.width <= max_width)
      assert.is_true(config.height <= max_height)
    end)

    it("pressing q in the float closes it", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node("output.ts")), stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down")
      h.drain()

      local win = find_float_win()
      assert.is_not_nil(win)

      -- Focus the float and press q
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_feedkeys("q", "x", false)

      assert.is_nil(find_float_win())
    end)

    it("pressing Esc in the float closes it", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node("output.ts")), stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down")
      h.drain()

      local win = find_float_win()
      assert.is_not_nil(win)

      -- Focus the float and press Escape
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

      assert.is_nil(find_float_win())
    end)

    it("shows a spinner notification while CLI is running", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system()
      table.insert(cleanups, restore_system)

      runner.run("down")

      -- A spinner notification should have been sent before the async call completes
      assert.is_true(#notifications >= 1)
      assert.equals(vim.log.levels.INFO, notifications[1].level)
    end)

    it("appends --symbol flag for up subcommand when symbol is provided", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/components/Button.ts"))
      local system_calls, restore_system = h.stub_system()
      table.insert(cleanups, restore_system)

      runner.run("up", "MyButton")

      assert.equals(1, #system_calls)
      local cmd = system_calls[1].cmd
      assert.is_truthy(cmd[1]:find("esmodtree"))
      assert.equals("--up", cmd[2])
      assert.equals("/project/src/components/Button.ts", cmd[3])
      assert.equals("--json", cmd[4])
      assert.equals("--symbol", cmd[5])
      assert.equals("MyButton", cmd[6])
    end)

    it("appends --symbol flag for updown subcommand when symbol is provided", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/components/Button.ts"))
      local system_calls, restore_system = h.stub_system()
      table.insert(cleanups, restore_system)

      runner.run("updown", "MyButton")

      assert.equals(1, #system_calls)
      local cmd = system_calls[1].cmd
      assert.is_truthy(cmd[1]:find("esmodtree"))
      assert.equals("--updown", cmd[2])
      assert.equals("/project/src/components/Button.ts", cmd[3])
      assert.equals("--json", cmd[4])
      assert.equals("--symbol", cmd[5])
      assert.equals("MyButton", cmd[6])
    end)

    it("does not include --symbol when symbol is nil", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local system_calls, restore_system = h.stub_system()
      table.insert(cleanups, restore_system)

      runner.run("up")

      assert.equals(1, #system_calls)
      local cmd = system_calls[1].cmd
      assert.equals(4, #cmd)
      assert.equals("--json", cmd[4])
    end)

    it("includes symbol in spinner notification", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system()
      table.insert(cleanups, restore_system)

      runner.run("up", "MyButton")

      assert.is_true(#notifications >= 1)
      assert.is_truthy(notifications[1].msg:find("MyButton"))
    end)

    it("opens location list instead of float when display is loclist", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node("src/index.ts", { node("src/foo.ts") })), stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down", nil, "loclist")
      h.drain()

      -- No float should be opened
      assert.is_nil(find_float_win())

      -- Location list should be populated
      local items = vim.fn.getloclist(0)
      assert.is_true(#items >= 2)
    end)

    it("still opens float when display is nil", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node("src/index.ts")), stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down", nil, nil)
      h.drain()

      local win = find_float_win()
      assert.is_not_nil(win)
    end)

    it("loclist entries have lnum=1 and col=1", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node("src/index.ts", { node("src/foo.ts") })), stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down", nil, "loclist")
      h.drain()

      local items = vim.fn.getloclist(0)
      for _, item in ipairs(items) do
        assert.equals(1, item.lnum)
        assert.equals(1, item.col)
      end
    end)

    it("loclist entries preserve tree-drawing characters in text", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        {
          code = 0,
          stdout = json(node("src/index.ts", { node("src/components/index.ts", {}, { markers = { "barrel" } }) })),
          stderr = "",
        },
      })
      table.insert(cleanups, restore_system)

      runner.run("down", nil, "loclist")
      h.drain()

      local items = vim.fn.getloclist(0)
      assert.equals(2, #items)
      assert.equals("src/index.ts", items[1].text)
      assert.equals("└── src/components/index.ts [barrel]", items[2].text)
    end)

    it("loclist title reflects subcommand", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node("src/index.ts")), stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down", nil, "loclist")
      h.drain()

      local info = vim.fn.getloclist(0, { title = 1 })
      assert.equals(" 🔎 Dependency tree ⇩ ", info.title)
    end)

    it("float title includes (symbol) suffix when symbol is provided", function()
      local _, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node("src/index.ts")), stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("up", "foo")
      h.drain()

      local win = find_float_win()
      assert.is_not_nil(win)
      local config = vim.api.nvim_win_get_config(win)
      assert.equals(" 🔎 Importer tree ⇧ (foo) ", config.title[1][1])
    end)

    it("loclist title includes (symbol) suffix when symbol is provided", function()
      local _, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node("src/index.ts")), stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("up", "foo", "loclist")
      h.drain()

      local info = vim.fn.getloclist(0, { title = 1 })
      assert.equals(" 🔎 Importer tree ⇧ (foo) ", info.title)
    end)
  end)

  describe("use_colors option", function()
    local function stub_ok_output(stdout)
      table.insert(cleanups, h.stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = stdout, stderr = "" },
      })
      table.insert(cleanups, restore_system)
    end

    local function float_extmark_count()
      local win = find_float_win()
      assert.is_not_nil(win)
      local buf = vim.api.nvim_win_get_buf(win)
      local ns = require("esmodtree.highlight").ns
      return #vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
    end

    it("applies highlights by default when setup() was never called", function()
      local _, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      stub_ok_output(json(node("src/index.ts", {}, { markers = { "entry" } })))

      runner.run("down")
      h.drain()

      assert.is_true(float_extmark_count() > 0)
    end)

    it("applies highlights when setup({ use_colors = true })", function()
      local _, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      require("esmodtree").setup({ use_colors = true })
      stub_ok_output(json(node("src/index.ts", {}, { markers = { "entry" } })))

      runner.run("down")
      h.drain()

      assert.is_true(float_extmark_count() > 0)
    end)

    it("skips highlights when setup({ use_colors = false })", function()
      local _, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      require("esmodtree").setup({ use_colors = false })
      stub_ok_output(json(node("src/index.ts", {}, { markers = { "entry" } })))

      runner.run("down")
      h.drain()

      assert.equals(0, float_extmark_count())
    end)

    it("applies highlights when setup({}) omits the option", function()
      local _, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      require("esmodtree").setup({})
      stub_ok_output(json(node("src/index.ts", {}, { markers = { "entry" } })))

      runner.run("down")
      h.drain()

      assert.is_true(float_extmark_count() > 0)
    end)
    it("applies extmarks to the loclist qf buffer when use_colors is on", function()
      local _, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        {
          code = 0,
          stdout = json(node("src/index.ts", { node("src/foo.ts") }, { markers = { "entry" } })),
          stderr = "",
        },
      })
      table.insert(cleanups, restore_system)
      table.insert(cleanups, function()
        pcall(vim.cmd, "lclose")
      end)

      runner.run("down", nil, "loclist")
      h.drain()

      local qfbufnr = vim.fn.getloclist(0, { qfbufnr = 0 }).qfbufnr
      assert.is_true(qfbufnr > 0)
      local ns = require("esmodtree.highlight").ns
      local marks = vim.api.nvim_buf_get_extmarks(qfbufnr, ns, 0, -1, {})
      assert.is_true(#marks > 0)
    end)

    it("disables builtin qf syntax on the Esmodtree loclist buffer", function()
      local _, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = json(node("src/index.ts", {}, { markers = { "entry" } })), stderr = "" },
      })
      table.insert(cleanups, restore_system)
      table.insert(cleanups, function()
        pcall(vim.cmd, "lclose")
      end)

      runner.run("down", nil, "loclist")
      h.drain()

      local qfbufnr = vim.fn.getloclist(0, { qfbufnr = 0 }).qfbufnr
      assert.is_true(qfbufnr > 0)
      assert.equals("off", vim.bo[qfbufnr].syntax)
    end)
  end)

  describe("_render_loclist", function()
    it("renders only the entry text, omitting filename/lnum/col prefix", function()
      local tree_line = "    \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80 src/components/index.ts [barrel]"
      vim.fn.setloclist(0, {}, " ", {
        title = "Esmodtree",
        items = {
          { filename = "src/index.ts", lnum = 1, col = 1, text = "src/index.ts [entry]" },
          { filename = "src/components/index.ts", lnum = 1, col = 1, text = tree_line },
        },
      })
      local info = vim.fn.getloclist(0, { id = 0, winid = 0 })
      local rendered = runner._render_loclist({
        winid = 0,
        id = info.id,
        start_idx = 1,
        end_idx = 2,
      })
      assert.equals(2, #rendered)
      assert.equals("src/index.ts [entry]", rendered[1])
      assert.equals(tree_line, rendered[2])
    end)
  end)
  describe("symbol locations", function()
    local function run_loclist(stdout, symbol)
      table.insert(cleanups, select(2, h.capture_notifications()))
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/target.ts"))
      local _, restore_system = h.stub_system({ { code = 0, stdout = stdout, stderr = "" } })
      table.insert(cleanups, restore_system)
      table.insert(cleanups, function()
        pcall(vim.cmd, "lclose")
      end)

      runner.run("updown", symbol, "loclist")
      h.drain()
    end

    local function tree_with_reference()
      return json(node("src/target.ts", {
        node("src/a.ts", {}, { reference = { line = 12, column = 5, kind = "usage" } }),
        node("src/b.ts", {}, { reference = { line = 1, column = 24, kind = "import" } }),
        node("src/c.ts"),
      }))
    end

    it("sets lnum and col on loclist items from the node reference", function()
      run_loclist(tree_with_reference(), "foo")

      local items = vim.fn.getloclist(0)
      assert.equals(4, #items)
      assert.equals(1, items[1].lnum)
      assert.equals(1, items[1].col)
      assert.equals(12, items[2].lnum)
      assert.equals(5, items[2].col)
      assert.equals(1, items[3].lnum)
      assert.equals(24, items[3].col)
      assert.equals(1, items[4].lnum)
      assert.equals(1, items[4].col)
    end)

    it("keeps the loclist text free of location information", function()
      run_loclist(tree_with_reference(), "foo")

      local items = vim.fn.getloclist(0)
      assert.equals("├── src/a.ts", items[2].text)
    end)

    it("renders dimmed 'line N col N' virtual text only for entries with a reference", function()
      run_loclist(tree_with_reference(), "foo")

      local qfbufnr = vim.fn.getloclist(0, { qfbufnr = 0 }).qfbufnr
      local ns = require("esmodtree.highlight").ns
      local texts = {}
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(qfbufnr, ns, 0, -1, { details = true })) do
        local virt = mark[4].virt_text
        if virt then
          texts[mark[2]] = { text = virt[1][1], hl = virt[1][2] }
        end
      end

      assert.is_nil(texts[0])
      assert.equals("  line 12 col 5", texts[1].text)
      assert.equals("EsmodtreeLocation", texts[1].hl)
      assert.equals("  line 1 col 24", texts[2].text)
      assert.is_nil(texts[3])
    end)

    it("shows the location text without a highlight group when use_colors is false", function()
      require("esmodtree").setup({ use_colors = false })
      run_loclist(tree_with_reference(), "foo")

      local qfbufnr = vim.fn.getloclist(0, { qfbufnr = 0 }).qfbufnr
      local ns = require("esmodtree.highlight").ns
      local marks = vim.api.nvim_buf_get_extmarks(qfbufnr, ns, 0, -1, { details = true })
      assert.equals(2, #marks)
      assert.equals("  line 12 col 5", marks[1][4].virt_text[1][1])
      assert.is_nil(marks[1][4].virt_text[1][2])
    end)

    it("renders a forest from --up output", function()
      local forest = json({
        node("src/a.ts", { node("src/target.ts") }, { reference = { line = 3, column = 7, kind = "usage" } }),
        node("src/b.ts", { node("src/target.ts") }),
      })
      table.insert(cleanups, select(2, h.capture_notifications()))
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/target.ts"))
      local _, restore_system = h.stub_system({ { code = 0, stdout = forest, stderr = "" } })
      table.insert(cleanups, restore_system)
      table.insert(cleanups, function()
        pcall(vim.cmd, "lclose")
      end)

      runner.run("up", "foo", "loclist")
      h.drain()

      local items = vim.fn.getloclist(0)
      assert.equals(4, #items)
      assert.equals("src/a.ts", items[1].text)
      assert.equals(3, items[1].lnum)
      assert.equals(7, items[1].col)
      assert.equals("└── src/target.ts", items[2].text)
      assert.equals("src/b.ts", items[3].text)
    end)

    it("notifies an error and shows nothing when the CLI output is not JSON", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({ { code = 0, stdout = "src/index.ts\n", stderr = "" } })
      table.insert(cleanups, restore_system)

      runner.run("down")
      h.drain()

      local last = notifications[#notifications]
      assert.equals(vim.log.levels.ERROR, last.level)
      assert.is_truthy(last.msg:find("parse"))
      assert.is_nil(find_float_win())
    end)

    it("does not add location text to the float", function()
      table.insert(cleanups, select(2, h.capture_notifications()))
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/target.ts"))
      local _, restore_system = h.stub_system({ { code = 0, stdout = tree_with_reference(), stderr = "" } })
      table.insert(cleanups, restore_system)

      runner.run("updown", "foo")
      h.drain()

      local win = find_float_win()
      assert.is_not_nil(win)
      local buf = vim.api.nvim_win_get_buf(win)
      local ns = require("esmodtree.highlight").ns
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
        assert.is_nil(mark[4].virt_text)
      end
    end)
  end)
end)
