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

describe("esmodtree.runner", function()
  local runner
  local cleanups

  before_each(function()
    cleanups = {}
    package.loaded["esmodtree.runner"] = nil
    package.loaded["esmodtree.util"] = nil
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

    it("executes esmodtree --down <path> --no-color for down subcommand", function()
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
      assert.equals("--no-color", cmd[4])
    end)

    it("executes esmodtree --updown <path> --no-color for updown subcommand", function()
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
      assert.equals("--no-color", cmd[4])
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
        { code = 0, stdout = "src/index.ts\n  src/foo.ts\n  src/bar.ts\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down")
      h.drain()

      local win = find_float_win()
      assert.is_not_nil(win)
    end)

    it("float buffer contains the CLI output lines", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = "line1\nline2\nline3\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down")
      h.drain()

      local win = find_float_win()
      assert.is_not_nil(win)
      local buf = vim.api.nvim_win_get_buf(win)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.equals("line1", lines[1])
      assert.equals("line2", lines[2])
      assert.equals("line3", lines[3])
    end)

    it("float buffer is a scratch buffer (nofile, not modifiable)", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = "output\n", stderr = "" },
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
        { code = 0, stdout = "output\n", stderr = "" },
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
      assert.equals("Esmodtree", config.title[1][1])
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
        many_lines[i] = long_line
      end
      local _, restore_system = h.stub_system({
        { code = 0, stdout = table.concat(many_lines, "\n") .. "\n", stderr = "" },
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
        { code = 0, stdout = "output\n", stderr = "" },
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
        { code = 0, stdout = "output\n", stderr = "" },
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
      assert.equals("--no-color", cmd[4])
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
      assert.equals("--no-color", cmd[4])
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
      assert.equals("--no-color", cmd[4])
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
        { code = 0, stdout = "src/index.ts\nsrc/foo.ts\n", stderr = "" },
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
        { code = 0, stdout = "src/index.ts\n", stderr = "" },
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
        { code = 0, stdout = "src/index.ts\nsrc/foo.ts\n", stderr = "" },
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
      local tree_line = "    \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80 src/components/index.ts [barrel]"
      local _, restore_system = h.stub_system({
        { code = 0, stdout = tree_line .. "\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down", nil, "loclist")
      h.drain()

      local items = vim.fn.getloclist(0)
      assert.equals(1, #items)
      assert.equals(tree_line, items[1].text)
    end)

    it("loclist title is Esmodtree", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_buf_name("/project/src/index.ts"))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = "src/index.ts\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      runner.run("down", nil, "loclist")
      h.drain()

      local info = vim.fn.getloclist(0, { title = 1 })
      assert.equals("Esmodtree", info.title)
    end)
  end)

  describe("_extract_path", function()
    it("extracts path from a plain root line", function()
      assert.equals("src/index.ts", runner._extract_path("src/index.ts [entry]"))
    end)

    it("extracts path from a root line without annotation", function()
      assert.equals("src/index.ts", runner._extract_path("src/index.ts"))
    end)

    it("extracts path from a line with tree branch characters", function()
      -- ├── src/app.ts
      local line = "    \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80 src/app.ts"
      assert.equals("src/app.ts", runner._extract_path(line))
    end)

    it("extracts path from a deeply indented line with └──", function()
      -- └── src/utils/format.ts
      local line = "    \xe2\x94\x82   \xe2\x94\x94\xe2\x94\x80\xe2\x94\x80 src/utils/format.ts"
      assert.equals("src/utils/format.ts", runner._extract_path(line))
    end)

    it("extracts path from a line with [barrel] annotation", function()
      local line = "    \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80 src/components/index.ts [barrel]"
      assert.equals("src/components/index.ts", runner._extract_path(line))
    end)

    it("extracts path from a line with [circular] annotation", function()
      local line = "                \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80 src/services/auth/auth.ts [circular]"
      assert.equals("src/services/auth/auth.ts", runner._extract_path(line))
    end)

    it("extracts path from a line with [dynamic] annotation", function()
      local line = "    \xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80 src/features/dynamic/lazy.ts [dynamic]"
      assert.equals("src/features/dynamic/lazy.ts", runner._extract_path(line))
    end)

    it("returns empty string for an empty line", function()
      assert.equals("", runner._extract_path(""))
    end)

    it("returns empty string for a whitespace-only line", function()
      assert.equals("", runner._extract_path("     "))
    end)

    it("extracts path from a line with only │ continuation characters", function()
      -- │   └── src/utils/helpers/constants.ts
      local line = "    \xe2\x94\x82   \xe2\x94\x82   \xe2\x94\x94\xe2\x94\x80\xe2\x94\x80 src/utils/helpers/constants.ts"
      assert.equals("src/utils/helpers/constants.ts", runner._extract_path(line))
    end)
  end)
end)
