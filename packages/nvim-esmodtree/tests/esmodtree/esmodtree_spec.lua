local h = require("helpers")

--- Delete a <Plug> mapping if it exists, ignoring errors.
local function del_plug(lhs)
  pcall(vim.keymap.del, "n", lhs)
end

--- List of all <Plug> mappings registered by setup().
local PLUG_MAPPINGS = {
  "<Plug>(esmodtree-down)",
  "<Plug>(esmodtree-up)",
  "<Plug>(esmodtree-updown)",
  "<Plug>(esmodtree-up-symbol)",
  "<Plug>(esmodtree-updown-symbol)",
  "<Plug>(esmodtree-ldown)",
  "<Plug>(esmodtree-lup)",
  "<Plug>(esmodtree-lupdown)",
  "<Plug>(esmodtree-lup-symbol)",
  "<Plug>(esmodtree-lupdown-symbol)",
}

describe("esmodtree", function()
  before_each(function()
    package.loaded["esmodtree"] = nil
    package.loaded["esmodtree.install"] = nil
    package.loaded["esmodtree.check"] = nil
    package.loaded["esmodtree.runner"] = nil
    package.loaded["esmodtree.util"] = nil
    -- Clean up any <Plug> mappings from previous tests
    for _, lhs in ipairs(PLUG_MAPPINGS) do
      del_plug(lhs)
    end
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

    it("registers all <Plug> mappings", function()
      local plugin = require("esmodtree")
      plugin.setup()

      for _, lhs in ipairs(PLUG_MAPPINGS) do
        local map = vim.fn.maparg(lhs, "n")
        assert.is_truthy(map ~= "", "expected mapping for " .. lhs)
      end
    end)
  end)

  describe("dispatch", function()
    it("dispatches to check when no subcommand given", function()
      local plugin = require("esmodtree")
      plugin.setup()

      -- dispatch({}) should not error — it delegates to check
      assert.has_no.errors(function()
        plugin.dispatch({})
      end)
    end)

    it("dispatches to check when called with nil", function()
      local plugin = require("esmodtree")
      plugin.setup()

      assert.has_no.errors(function()
        plugin.dispatch(nil)
      end)
    end)

    it("notifies error for unrecognized subcommand", function()
      local plugin = require("esmodtree")
      plugin.setup()

      local notifications, restore_notify = h.capture_notifications()

      plugin.dispatch({ "bogus" })

      restore_notify()

      assert.equals(1, #notifications)
      assert.is_truthy(notifications[1].msg:find("bogus"))
      assert.equals(vim.log.levels.ERROR, notifications[1].level)
    end)

    it("dispatches down to runner module", function()
      local plugin = require("esmodtree")
      plugin.setup()

      local called_subcmd, called_symbol
      package.loaded["esmodtree.runner"] = {
        run = function(subcmd, symbol)
          called_subcmd = subcmd
          called_symbol = symbol
        end,
      }

      plugin.dispatch({ "down" })

      assert.equals("down", called_subcmd)
      assert.is_nil(called_symbol)
    end)

    it("dispatches up to runner module", function()
      local plugin = require("esmodtree")
      plugin.setup()

      local called_subcmd, called_symbol
      package.loaded["esmodtree.runner"] = {
        run = function(subcmd, symbol)
          called_subcmd = subcmd
          called_symbol = symbol
        end,
      }

      plugin.dispatch({ "up" })

      assert.equals("up", called_subcmd)
      assert.is_nil(called_symbol)
    end)

    it("dispatches up with symbol to runner module", function()
      local plugin = require("esmodtree")
      plugin.setup()

      local called_subcmd, called_symbol
      package.loaded["esmodtree.runner"] = {
        run = function(subcmd, symbol)
          called_subcmd = subcmd
          called_symbol = symbol
        end,
      }

      plugin.dispatch({ "up", "MyButton" })

      assert.equals("up", called_subcmd)
      assert.equals("MyButton", called_symbol)
    end)

    it("dispatches updown with symbol to runner module", function()
      local plugin = require("esmodtree")
      plugin.setup()

      local called_subcmd, called_symbol, called_display
      package.loaded["esmodtree.runner"] = {
        run = function(subcmd, symbol, display)
          called_subcmd = subcmd
          called_symbol = symbol
          called_display = display
        end,
      }

      plugin.dispatch({ "updown", "MyButton" })

      assert.equals("updown", called_subcmd)
      assert.equals("MyButton", called_symbol)
    end)

    it("dispatches ldown to runner with loclist display", function()
      local plugin = require("esmodtree")
      plugin.setup()

      local called_subcmd, called_symbol, called_display
      package.loaded["esmodtree.runner"] = {
        run = function(subcmd, symbol, display)
          called_subcmd = subcmd
          called_symbol = symbol
          called_display = display
        end,
      }

      plugin.dispatch({ "ldown" })

      assert.equals("down", called_subcmd)
      assert.is_nil(called_symbol)
      assert.equals("loclist", called_display)
    end)

    it("dispatches lup to runner with loclist display", function()
      local plugin = require("esmodtree")
      plugin.setup()

      local called_subcmd, called_symbol, called_display
      package.loaded["esmodtree.runner"] = {
        run = function(subcmd, symbol, display)
          called_subcmd = subcmd
          called_symbol = symbol
          called_display = display
        end,
      }

      plugin.dispatch({ "lup" })

      assert.equals("up", called_subcmd)
      assert.is_nil(called_symbol)
      assert.equals("loclist", called_display)
    end)

    it("dispatches lupdown with symbol to runner with loclist display", function()
      local plugin = require("esmodtree")
      plugin.setup()

      local called_subcmd, called_symbol, called_display
      package.loaded["esmodtree.runner"] = {
        run = function(subcmd, symbol, display)
          called_subcmd = subcmd
          called_symbol = symbol
          called_display = display
        end,
      }

      plugin.dispatch({ "lupdown", "MyButton" })

      assert.equals("updown", called_subcmd)
      assert.equals("MyButton", called_symbol)
      assert.equals("loclist", called_display)
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
      assert.is_truthy(vim.tbl_contains(completions, "ldown"))
      assert.is_truthy(vim.tbl_contains(completions, "lup"))
      assert.is_truthy(vim.tbl_contains(completions, "lupdown"))
    end)
  end)
end)
