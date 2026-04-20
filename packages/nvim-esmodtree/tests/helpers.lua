local M = {}

--- Captures vim.notify calls. Returns the notifications table and a restore function.
function M.capture_notifications()
  local notifications = {}
  local original_notify = vim.notify
  vim.notify = function(msg, level, opts)
    table.insert(notifications, { msg = msg, level = level, opts = opts })
  end
  return notifications, function()
    vim.notify = original_notify
  end
end

--- Stubs vim.fn.executable to return controlled values from a map.
function M.stub_executable(map)
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

--- Stubs vim.fn.filereadable to return controlled values for matching path patterns.
function M.stub_filereadable(map)
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

--- Stubs vim.fn.readfile to return controlled content for matching path patterns.
function M.stub_readfile(map)
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

--- Stubs vim.system to capture calls and auto-complete with scripted results.
--- `results` is a list of {code, stdout, stderr} tables, one per expected vim.system call.
--- Each call completes immediately via vim.schedule with the corresponding result.
function M.stub_system(results)
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

--- Drain all pending vim.schedule callbacks
function M.drain()
  vim.wait(200, function()
    return false
  end)
end

return M
