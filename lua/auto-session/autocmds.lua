local Lib = require "auto-session.lib"

local M = {}

---@private
---Setup autocmds for DirChangedPre and DirChanged
---@param config table auto session config
---@param AutoSession table auto session instance
M.setup_autocmds = function(config, AutoSession)
  if not config.cwd_change_handling or not config.cwd_change_handling.restore_upcoming_session then
    Lib.logger.debug "cwd_change_handling is disabled, skipping setting DirChangedPre and DirChanged autocmd handling"
    return
  end

  local conf = config.cwd_change_handling

  vim.api.nvim_create_autocmd("DirChangedPre", {
    callback = function()
      Lib.logger.debug "DirChangedPre"
      Lib.logger.debug {
        cwd = vim.fn.getcwd(),
        target = vim.v.event.directory,
        ["changed window"] = tostring(vim.v.event.changed_window),
        scope = vim.v.event.scope,
      }

      -- Don't want to save session if dir change was triggered
      -- by a window change. This will corrupt the session data,
      -- mixing the two different directory sessions
      if vim.v.event.changed_window then
        return
      end

      if AutoSession.restore_in_progress or vim.g.SessionLoad then
        Lib.logger.debug "DirChangedPre: restore_in_progress/vim.g.SessionLoad is true, ignoring this event"
        -- NOTE: We don't call the cwd_changed_hook here
        -- I think that's probably the right choice because I assume that event is mostly
        -- for preparing sessions for save/restoring but we don't want to do that when we're
        -- already restoring a session
        return
      end

      AutoSession.AutoSaveSession()

      if type(conf.pre_cwd_changed_hook) == "function" then
        conf.pre_cwd_changed_hook()
      end
    end,
    pattern = "global",
  })

  if conf.restore_upcoming_session then
    vim.api.nvim_create_autocmd("DirChanged", {
      callback = function()
        Lib.logger.debug "DirChanged"
        Lib.logger.debug("  cwd: " .. vim.fn.getcwd())
        Lib.logger.debug("  changed window: " .. tostring(vim.v.event.changed_window))
        Lib.logger.debug("  scope: " .. vim.v.event.scope)

        -- see above
        if vim.v.event.changed_window then
          return
        end

        if AutoSession.restore_in_progress or vim.g.SessionLoad then
          -- NOTE: We don't call the cwd_changed_hook here (or in the other case below)
          -- I think that's probably the right choice because I assume that event is mostly
          -- for preparing sessions for save/restoring but we don't want to do that when we're
          -- already restoring a session
          Lib.logger.debug "DirChangedPre: restore_in_progress/vim.g.SessionLoad is true, ignoring this event"
          return
        end

        -- all buffers should've been deleted in `DirChangedPre`, something probably went wrong
        if Lib.has_open_buffers() then
          Lib.logger.debug "Cancelling session restore"
          return
        end

        local success = AutoSession.AutoRestoreSession()

        if not success then
          Lib.logger.info("Could not load session for: " .. vim.fn.getcwd())
          -- Don't return, still dispatch the hook below
        end

        if type(conf.post_cwd_changed_hook) == "function" then
          conf.post_cwd_changed_hook()
        end
      end,
      pattern = "global",
    })
  end
end

return M
