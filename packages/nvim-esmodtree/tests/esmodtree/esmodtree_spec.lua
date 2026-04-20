local function capture_notifications()
  local notifications = {}
  local original_notify = vim.notify
  vim.notify = function(msg, level, opts)
    table.insert(notifications, { msg = msg, level = level, opts = opts })
  end
  return notifications, function()
    vim.notify = original_notify
  end
end

describe("esmodtree", function()
  before_each(function()
    package.loaded["esmodtree"] = nil
    package.loaded["esmodtree.install"] = nil
    package.loaded["esmodtree.check"] = nil
    package.loaded["esmodtree.runner"] = nil
    package.loaded["esmodtree.util"] = nil
  end)

  describe("setup", function()
    it("accepts no arguments without error", function()
      local plugin = require("esmodtree")
      assert.has_no.errors(function()
        plugin.setup()
      end)
    end)

    it("accepts an empty config table", function()
      local plugin = require("esmodtree")
      assert.has_no.errors(function()
        plugin.setup({})
      end)
    end)
  end)

  describe("dispatch", function()
    it("dispatches to check when no subcommand given", function()
      local plugin = require("esmodtree")
      plugin.setup()

      -- dispatch(nil) should not error — it delegates to check
      assert.has_no.errors(function()
        plugin.dispatch(nil)
      end)
    end)

    it("notifies error for unrecognized subcommand", function()
      local plugin = require("esmodtree")
      plugin.setup()

      local notifications, restore_notify = capture_notifications()

      plugin.dispatch("bogus")

      restore_notify()

      assert.equals(1, #notifications)
      assert.is_truthy(notifications[1].msg:find("bogus"))
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
    end)

    it("notifies error for down/up before phase 2 implementation", function()
      local plugin = require("esmodtree")
      plugin.setup()

      local notifications, restore_notify = capture_notifications()

      plugin.dispatch("down")

      restore_notify()

      assert.equals(1, #notifications)
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
    end)
  end)

  describe("complete", function()
    it("returns subcommand list for tab completion", function()
      local plugin = require("esmodtree")
      plugin.setup()

      local completions = plugin.complete()

      assert.is_truthy(vim.tbl_contains(completions, "down"))
      assert.is_truthy(vim.tbl_contains(completions, "up"))
      assert.is_truthy(vim.tbl_contains(completions, "install"))
      assert.is_truthy(vim.tbl_contains(completions, "check"))
    end)
  end)
end)
