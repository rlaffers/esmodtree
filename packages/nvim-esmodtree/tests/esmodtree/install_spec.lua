local h = require("helpers")

-- Read the expected CLI version from cli-version.txt (same resolution as the install module)
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
local expected_version = vim.trim(vim.fn.readfile(plugin_root .. "/cli-version.txt")[1])
local expected_cli_dist = vim.fn.fnamemodify(plugin_root .. "/../cli/dist/cli.js", ":p")
local expected_bin = plugin_root .. "/node_modules/.bin/esmodtree"

describe("esmodtree.install", function()
  local install
  local cleanups

  before_each(function()
    cleanups = {}
    package.loaded["esmodtree.install"] = nil
    install = require("esmodtree.install")
  end)

  -- Drain pending callbacks FIRST (while stubs are still active), then restore
  after_each(function()
    h.drain()
    h.drain()
    for _, fn in ipairs(cleanups) do
      fn()
    end
  end)

  describe("run", function()
    it("notifies error when node is not available", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_executable({ node = 0 }))

      install.run()

      assert.equals(1, #notifications)
      assert.is_truthy(notifications[1].msg:find("node"))
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
    end)

    it("uses pnpm when both pnpm and npm are available", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_executable({ node = 1, pnpm = 1, npm = 1 }))
      local system_calls, restore_system = h.stub_system()
      table.insert(cleanups, restore_system)

      install.run()

      assert.is_true(#system_calls >= 1)
      assert.equals("pnpm", system_calls[1].cmd[1])
    end)

    it("falls back to npm when pnpm is not available", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_executable({ node = 1, pnpm = 0, npm = 1 }))
      local system_calls, restore_system = h.stub_system()
      table.insert(cleanups, restore_system)

      install.run()

      assert.is_true(#system_calls >= 1)
      assert.equals("npm", system_calls[1].cmd[1])
    end)

    it("notifies error when neither pnpm nor npm is available", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_executable({ node = 1, pnpm = 0, npm = 0 }))

      install.run()

      assert.equals(1, #notifications)
      assert.is_truthy(notifications[1].msg:find("pnpm") or notifications[1].msg:find("npm"))
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
    end)

    it("passes the version from cli-version.txt to the install command", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_executable({ node = 1, pnpm = 1, npm = 1 }))
      local system_calls, restore_system = h.stub_system()
      table.insert(cleanups, restore_system)

      install.run()

      assert.is_true(#system_calls >= 1)
      local cmd = system_calls[1].cmd
      assert.equals("pnpm", cmd[1])
      assert.equals("add", cmd[2])
      assert.equals("--ignore-workspace", cmd[3])
      assert.equals("@esmodtree/cli@" .. expected_version, cmd[4])
    end)

    it("verifies the binary after successful install and notifies success", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_executable({ node = 1, pnpm = 1, npm = 1 }))
      local system_calls, restore_system = h.stub_system({
        { code = 0, stdout = "", stderr = "" },
        { code = 0, stdout = expected_version .. "\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      install.run()
      h.drain()
      h.drain()

      assert.equals(2, #system_calls)
      local verify_cmd = system_calls[2].cmd
      assert.is_truthy(verify_cmd[1]:find("esmodtree"))
      assert.equals("--version", verify_cmd[2])

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find(expected_version))
      assert.equals(vim.log.levels.INFO, last.level)
    end)

    it("notifies error when install command fails", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_executable({ node = 1, pnpm = 1, npm = 1 }))
      local system_calls, restore_system = h.stub_system({
        { code = 1, stdout = "", stderr = "ERR! something went wrong" },
      })
      table.insert(cleanups, restore_system)

      install.run()
      h.drain()

      assert.equals(1, #system_calls)

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find("failed"))
      assert.equals(vim.log.levels.ERROR, last.level)
    end)

    it("notifies error when binary verification fails", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_executable({ node = 1, pnpm = 1, npm = 1 }))
      local system_calls, restore_system = h.stub_system({
        { code = 0, stdout = "", stderr = "" },
        { code = 1, stdout = "", stderr = "command not found" },
      })
      table.insert(cleanups, restore_system)

      install.run()
      h.drain()
      h.drain()

      assert.equals(2, #system_calls)

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find("verification failed"))
      assert.equals(vim.log.levels.ERROR, last.level)
    end)
  end)

  describe("local dev install (USE_LOCAL_CLI=true)", function()
    it("takes the local path when .env has USE_LOCAL_CLI=true and dist exists", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_executable({ node = 1 }))
      table.insert(
        cleanups,
        h.stub_filereadable({
          [".env"] = 1,
          ["cli.js"] = 1,
        })
      )
      table.insert(
        cleanups,
        h.stub_readfile({
          [".env"] = { "USE_LOCAL_CLI=true" },
        })
      )
      local mkdir_calls, restore_mkdir = h.stub_mkdir()
      table.insert(cleanups, restore_mkdir)
      local write_calls, restore_writefile = h.stub_writefile()
      table.insert(cleanups, restore_writefile)
      local system_calls, restore_system = h.stub_system({
        { code = 0, stdout = "", stderr = "" }, -- chmod
        { code = 0, stdout = "1.0.0\n", stderr = "" }, -- --version
      })
      table.insert(cleanups, restore_system)

      install.run()
      h.drain()
      h.drain()

      -- Should not have called pnpm/npm
      assert.equals("chmod", system_calls[1].cmd[1])
      assert.equals("+x", system_calls[1].cmd[2])
      -- bin path ends with the expected suffix regardless of absolute vs relative root
      assert.is_truthy(system_calls[1].cmd[3]:find("node_modules/.bin/esmodtree", 1, true))

      -- Should have written wrapper script to same path as chmod target
      assert.equals(1, #write_calls)
      assert.equals(system_calls[1].cmd[3], write_calls[1].path)
      assert.equals("#!/bin/sh", write_calls[1].lines[1])
      assert.is_truthy(write_calls[1].lines[2]:find("cli.js", 1, true))

      -- Should have created bin dir
      assert.equals(1, #mkdir_calls)

      -- Should notify success
      local last = notifications[#notifications]
      assert.equals(vim.log.levels.INFO, last.level)
      assert.is_truthy(last.msg:find("local CLI"))
    end)

    it("notifies error when dist cli.js is missing", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_executable({ node = 1 }))
      table.insert(
        cleanups,
        h.stub_filereadable({
          [".env"] = 1,
          ["cli.js"] = 0,
        })
      )
      table.insert(
        cleanups,
        h.stub_readfile({
          [".env"] = { "USE_LOCAL_CLI=true" },
        })
      )

      install.run()

      assert.equals(2, #notifications)
      local last = notifications[#notifications]
      assert.equals(vim.log.levels.ERROR, last.level)
      assert.is_truthy(last.msg:find("build"))
    end)

    it("notifies error when chmod fails", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_executable({ node = 1 }))
      table.insert(
        cleanups,
        h.stub_filereadable({
          [".env"] = 1,
          ["cli.js"] = 1,
        })
      )
      table.insert(
        cleanups,
        h.stub_readfile({
          [".env"] = { "USE_LOCAL_CLI=true" },
        })
      )
      table.insert(cleanups, select(2, h.stub_mkdir()))
      table.insert(cleanups, select(2, h.stub_writefile()))
      local _, restore_system = h.stub_system({
        { code = 1, stdout = "", stderr = "operation not permitted" }, -- chmod fails
      })
      table.insert(cleanups, restore_system)

      install.run()
      h.drain()

      local last = notifications[#notifications]
      assert.equals(vim.log.levels.ERROR, last.level)
      assert.is_truthy(last.msg:find("executable"))
    end)

    it("notifies error when binary verification fails after local install", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_executable({ node = 1 }))
      table.insert(
        cleanups,
        h.stub_filereadable({
          [".env"] = 1,
          ["cli.js"] = 1,
        })
      )
      table.insert(
        cleanups,
        h.stub_readfile({
          [".env"] = { "USE_LOCAL_CLI=true" },
        })
      )
      table.insert(cleanups, select(2, h.stub_mkdir()))
      table.insert(cleanups, select(2, h.stub_writefile()))
      local _, restore_system = h.stub_system({
        { code = 0, stdout = "", stderr = "" }, -- chmod ok
        { code = 1, stdout = "", stderr = "error" }, -- --version fails
      })
      table.insert(cleanups, restore_system)

      install.run()
      h.drain()
      h.drain()

      local last = notifications[#notifications]
      assert.equals(vim.log.levels.ERROR, last.level)
      assert.is_truthy(last.msg:find("verification failed"))
    end)

    it("falls through to npm/pnpm install when USE_LOCAL_CLI is absent", function()
      local notifications, restore_notify = h.capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, h.stub_executable({ node = 1, pnpm = 1, npm = 1 }))
      -- .env is not readable
      table.insert(cleanups, h.stub_filereadable({ [".env"] = 0 }))
      local system_calls, restore_system = h.stub_system()
      table.insert(cleanups, restore_system)

      install.run()

      assert.is_true(#system_calls >= 1)
      assert.equals("pnpm", system_calls[1].cmd[1])
    end)
  end)
end)
