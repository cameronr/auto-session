---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("The suppress dirs config", function()
  require("auto-session").setup {
    auto_session_root_dir = TL.session_dir,
    auto_session_suppress_dirs = { vim.fn.getcwd() },
  }

  TL.clearSessionFilesAndBuffers()
  vim.cmd(":e " .. TL.test_file)

  it("doesn't save a session for a suppressed dir", function()
    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").AutoSaveSession()

    -- Make sure the session was not created
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)

  require("auto-session").setup {
    auto_session_root_dir = TL.session_dir,
    auto_session_suppress_dirs = { "/dummy" },
  }

  it("saves a session for a non-suppressed dir", function()
    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").AutoSaveSession()

    -- Make sure the session was created
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Make sure the session has our buffer
    TL.assertSessionHasFile(TL.default_session_path, TL.test_file)
  end)

  TL.clearSessionFilesAndBuffers()
  vim.cmd(":e " .. TL.test_file)

  require("auto-session").setup {
    auto_session_root_dir = TL.session_dir,
    auto_session_suppress_dirs = { vim.fn.getcwd() },
    auto_session_allowed_dirs = { vim.fn.getcwd() },
  }

  it("doesn't save a session for a suppressed dir even if also an allowed dir", function()
    ---@diagnostic disable-next-line: missing-parameter
    require("auto-session").AutoSaveSession()

    -- Make sure the session was not created
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))
  end)
end)
