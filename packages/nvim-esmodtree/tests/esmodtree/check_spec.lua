local h = require("helpers")

describe("esmodtree.check", function()
  local check
  local cleanups

  before_each(function()
    cleanups = {}
    package.loaded["esmodtree.check"] = nil
    package.loaded["esmodtree.util"] = nil
    check = require("esmodtree.check")
  end)

  after_each(function()
    h.drain()
    h.drain()
    for _, fn in ipairs(cleanups) do
      fn()
    end
  end)

  describe("run", function()
    it("notifies error when CLI binary is missing", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_filereadable({ ["node_modules/.bin/esmodtree"] = 0 }))

      check.run()
      h.drain()

      assert.equals(1, #notifications)
      assert.is_truthy(notifications[1].msg:find("install"))
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
    end)

    it("notifies OK when installed version matches required version", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, h.stub_readfile({ ["cli-version.txt"] = { "1.2.3" } }))
      local system_calls, restore_system = h.stub_system({
        { code = 0, stdout = "1.2.3\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      check.run()
      h.drain()
      h.drain()

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find("1.2.3"))
      assert.equals(vim.log.levels.INFO, last.level)
    end)

    it("notifies warning when installed version differs from required version", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, h.stub_readfile({ ["cli-version.txt"] = { "2.0.0" } }))
      local system_calls, restore_system = h.stub_system({
        { code = 0, stdout = "1.0.0\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      check.run()
      h.drain()
      h.drain()

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find("1.0.0"))
      assert.is_truthy(last.msg:find("2.0.0"))
      assert.equals(vim.log.levels.WARN, last.level)
    end)

    it("resolves 'latest' via package manager and notifies OK when matching", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, h.stub_readfile({ ["cli-version.txt"] = { "latest" } }))
      table.insert(cleanups, h.stub_executable({ pnpm = 1, npm = 1 }))
      -- First call: esmodtree --version, second call: pnpm info @esmodtree/cli version
      local system_calls, restore_system = h.stub_system({
        { code = 0, stdout = "1.5.0\n", stderr = "" },
        { code = 0, stdout = "1.5.0\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      check.run()
      h.drain()
      h.drain()
      h.drain()

      -- Should have made 2 vim.system calls
      assert.equals(2, #system_calls)
      -- Second call should be pnpm info
      assert.equals("pnpm", system_calls[2].cmd[1])

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find("1.5.0"))
      assert.equals(vim.log.levels.INFO, last.level)
    end)

    it("resolves 'latest' and notifies warning on mismatch", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, h.stub_readfile({ ["cli-version.txt"] = { "latest" } }))
      table.insert(cleanups, h.stub_executable({ pnpm = 0, npm = 1 }))
      -- First call: esmodtree --version, second call: npm view @esmodtree/cli version
      local system_calls, restore_system = h.stub_system({
        { code = 0, stdout = "1.0.0\n", stderr = "" },
        { code = 0, stdout = "2.0.0\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      check.run()
      h.drain()
      h.drain()
      h.drain()

      assert.equals(2, #system_calls)
      -- Second call should be npm view (since pnpm = 0)
      assert.equals("npm", system_calls[2].cmd[1])

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find("1.0.0"))
      assert.is_truthy(last.msg:find("2.0.0"))
      assert.equals(vim.log.levels.WARN, last.level)
    end)
  end)
end)
