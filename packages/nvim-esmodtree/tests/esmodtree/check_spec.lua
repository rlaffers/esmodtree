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

-- Test helper: stubs vim.fn.filereadable to return controlled values
local function stub_filereadable(map)
  local original = vim.fn.filereadable
  vim.fn.filereadable = function(path)
    for pattern, val in pairs(map) do
      if path:find(pattern, 1, true) then
        return val
      end
    end
    return original(path)
  end
  return function()
    vim.fn.filereadable = original
  end
end

-- Test helper: stubs vim.fn.readfile to return controlled content for matching paths
local function stub_readfile(map)
  local original = vim.fn.readfile
  vim.fn.readfile = function(path)
    for pattern, lines in pairs(map) do
      if path:find(pattern, 1, true) then
        return lines
      end
    end
    return original(path)
  end
  return function()
    vim.fn.readfile = original
  end
end

-- Test helper: stubs vim.system to capture calls and auto-complete with scripted results.
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

-- Drain all pending vim.schedule callbacks
local function drain()
  vim.wait(200, function()
    return false
  end)
end

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
    drain()
    drain()
    for _, fn in ipairs(cleanups) do
      fn()
    end
  end)

  describe("run", function()
    it("notifies error when CLI binary is missing", function()
      local notifications, restore_notify = capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 0 }))

      check.run()

      assert.equals(1, #notifications)
      assert.is_truthy(notifications[1].msg:find("install"))
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
    end)

    it("notifies OK when installed version matches required version", function()
      local notifications, restore_notify = capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_readfile({ ["cli-version.txt"] = { "1.2.3" } }))
      local system_calls, restore_system = stub_system({
        { code = 0, stdout = "1.2.3\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      check.run()
      drain()
      drain()

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find("1.2.3"))
      assert.equals(vim.log.levels.INFO, last.level)
    end)

    it("notifies warning when installed version differs from required version", function()
      local notifications, restore_notify = capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_readfile({ ["cli-version.txt"] = { "2.0.0" } }))
      local system_calls, restore_system = stub_system({
        { code = 0, stdout = "1.0.0\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      check.run()
      drain()
      drain()

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find("1.0.0"))
      assert.is_truthy(last.msg:find("2.0.0"))
      assert.equals(vim.log.levels.WARN, last.level)
    end)

    it("resolves 'latest' via package manager and notifies OK when matching", function()
      local notifications, restore_notify = capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_readfile({ ["cli-version.txt"] = { "latest" } }))
      table.insert(cleanups, stub_executable({ pnpm = 1, npm = 1 }))
      -- First call: esmodtree --version, second call: pnpm info @esmodtree/cli version
      local system_calls, restore_system = stub_system({
        { code = 0, stdout = "1.5.0\n", stderr = "" },
        { code = 0, stdout = "1.5.0\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      check.run()
      drain()
      drain()
      drain()

      -- Should have made 2 vim.system calls
      assert.equals(2, #system_calls)
      -- Second call should be pnpm info
      assert.equals("pnpm", system_calls[2].cmd[1])

      local last = notifications[#notifications]
      assert.is_truthy(last.msg:find("1.5.0"))
      assert.equals(vim.log.levels.INFO, last.level)
    end)

    it("resolves 'latest' and notifies warning on mismatch", function()
      local notifications, restore_notify = capture_notifications()
      table.insert(cleanups, restore_notify)
      table.insert(cleanups, stub_filereadable({ ["node_modules/.bin/esmodtree"] = 1 }))
      table.insert(cleanups, stub_readfile({ ["cli-version.txt"] = { "latest" } }))
      table.insert(cleanups, stub_executable({ pnpm = 0, npm = 1 }))
      -- First call: esmodtree --version, second call: npm view @esmodtree/cli version
      local system_calls, restore_system = stub_system({
        { code = 0, stdout = "1.0.0\n", stderr = "" },
        { code = 0, stdout = "2.0.0\n", stderr = "" },
      })
      table.insert(cleanups, restore_system)

      check.run()
      drain()
      drain()
      drain()

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
