-- Test helper: captures vim.notify calls
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

-- Test helper: stubs vim.fn.executable to return controlled values
local function stub_executable(map)
  local original = vim.fn.executable
  vim.fn.executable = function(name)
    if map[name] ~= nil then
      return map[name]
    end
    return original(name)
  end
  return function()
    vim.fn.executable = original
  end
end

-- Test helper: stubs vim.system to capture calls and auto-complete with scripted results.
-- `results` is a list of {code, stdout, stderr} tables, one per expected vim.system call.
-- Each call completes immediately via vim.schedule with the corresponding result.
local function stub_system(results)
  results = results or {}
  local calls = {}
  local original = vim.system
  local call_index = 0

  vim.system = function(cmd, opts, on_exit)
    call_index = call_index + 1
    table.insert(calls, { cmd = cmd, opts = opts })

    local result = results[call_index] or { code = 0, stdout = "", stderr = "" }

    if on_exit then
      vim.schedule(function()
        on_exit(result)
      end)
    end

    return { pid = 0 }
  end

  local function restore()
    vim.system = original
  end

  return calls, restore
end

-- Drain all pending vim.schedule callbacks
local function drain()
  vim.wait(200, function()
    return false
  end)
end

-- Read the expected CLI version from cli-version.txt (same resolution as the install module)
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
local expected_version = vim.trim(vim.fn.readfile(plugin_root .. "/cli-version.txt")[1])

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
    drain()
    drain()
    for _, fn in ipairs(cleanups) do
      fn()
    end
  end)

  describe("run", function()
    it("notifies error when node is not available", function()
      local notifications, restore_notify = capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_executable({ node = 0 }))

      install.run()

      assert.equals(1, #notifications)
      assert.is_truthy(notifications[1].msg:find("node"))
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
    end)

    it("uses pnpm when both pnpm and npm are available", function()
      local notifications, restore_notify = capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_executable({ node = 1, pnpm = 1, npm = 1 }))
      local system_calls, restore_system = stub_system()
      table.insert(cleanups, restore_system)

      install.run()

      assert.is_true(#system_calls >= 1)
      assert.equals("pnpm", system_calls[1].cmd[1])
    end)

    it("falls back to npm when pnpm is not available", function()
      local notifications, restore_notify = capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_executable({ node = 1, pnpm = 0, npm = 1 }))
      local system_calls, restore_system = stub_system()
      table.insert(cleanups, restore_system)

      install.run()

      assert.is_true(#system_calls >= 1)
      assert.equals("npm", system_calls[1].cmd[1])
    end)

    it("notifies error when neither pnpm nor npm is available", function()
      local notifications, restore_notify = capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_executable({ node = 1, pnpm = 0, npm = 0 }))

      install.run()

      assert.equals(1, #notifications)
      assert.is_truthy(notifications[1].msg:find("pnpm") or notifications[1].msg:find("npm"))
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
    end)

    it("passes the version from cli-version.txt to the install command", function()
      local notifications, restore_notify = capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_executable({ node = 1, pnpm = 1, npm = 1 }))
      local system_calls, restore_system = stub_system()
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
      local notifications, restore_notify = capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_executable({ node = 1, pnpm = 1, npm = 1 }))
      local system_calls, restore_system = stub_system({
        { code = 0, stdout = "", stderr = "" },
        { code = 0, stdout = expected_version .. "\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      install.run()
      drain()
      drain()

      assert.equals(2, #system_calls)
      local verify_cmd = system_calls[2].cmd
      assert.is_truthy(verify_cmd[1]:find("esmodtree"))
      assert.equals("--version", verify_cmd[2])

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find(expected_version))
      assert.equals(vim.log.levels.INFO, last.level)
    end)

    it("notifies error when install command fails", function()
      local notifications, restore_notify = capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_executable({ node = 1, pnpm = 1, npm = 1 }))
      local system_calls, restore_system = stub_system({
        { code = 1, stdout = "", stderr = "ERR! something went wrong" },
      })
      table.insert(cleanups, restore_system)

      install.run()
      drain()

      assert.equals(1, #system_calls)

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find("failed"))
      assert.equals(vim.log.levels.ERROR, last.level)
    end)

    it("notifies error when binary verification fails", function()
      local notifications, restore_notify = capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_executable({ node = 1, pnpm = 1, npm = 1 }))
      local system_calls, restore_system = stub_system({
        { code = 0, stdout = "", stderr = "" },
        { code = 1, stdout = "", stderr = "command not found" },
      })
      table.insert(cleanups, restore_system)

      install.run()
      drain()
      drain()

      assert.equals(2, #system_calls)

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find("verification failed"))
      assert.equals(vim.log.levels.ERROR, last.level)
    end)
  end)
end)
