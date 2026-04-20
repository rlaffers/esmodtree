---@class CustomModule
local M = {}

---@param greeting string
---@return nil
M.my_first_function = function(greeting)
  print(greeting)
end

return M
