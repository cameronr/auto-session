local Lib = require "auto-session.lib"

local M = {
  conf = {},
  functions = {},
}

function M.setup(config, functions)
  M.conf = vim.tbl_deep_extend("force", config, M.conf)
  M.functions = functions
end

local function get_alternate_session()
  local filepath = M.conf.session_control.control_dir .. M.conf.session_control.control_filename

  if vim.fn.filereadable(filepath) == 1 then
    local content = vim.fn.readfile(filepath)[1] or "{}"
    local json = vim.json.decode(content) or {} -- should never hit the or clause since we're defaulting to a string for content

    local sessions = {
      current = json.current,
      alternate = json.alternate,
    }

    Lib.logger.debug("get_alternate_session", { sessions = sessions, content = content })

    if sessions.current ~= sessions.alternate then
      return sessions.alternate
    end

    Lib.logger.info "Current session is the same as alternate!"
  end
end

local function source_session(selection, prompt_bufnr)
  if prompt_bufnr then
    local actions = require "telescope.actions"
    actions.close(prompt_bufnr)
  end

  vim.defer_fn(function()
    local cwd_change_handling_conf = M.functions.conf.cwd_change_handling

    -- If cwd_change_handling is true, the current session will be saved in the DirChangedPre AutoCmd
    -- and the new session will be restored in DirChanged
    if type(cwd_change_handling_conf) == "table" and cwd_change_handling_conf.restore_upcoming_session then
      -- Take advatage of cwd_change_handling behaviour for switching sessions
      Lib.logger.debug "Triggering vim.fn.chdir since cwd_change_handling feature is enabled"
      vim.fn.chdir(M.functions.format_file_name(type(selection) == "table" and selection.filename or selection))
    else
      -- TODO: Since cwd_change_handling is disabled, we save and restore here. This would probably be better
      -- handled in AutoSession itself since the same case comes up if the built in picker is used
      -- (e.g. :Autosession search).
      Lib.logger.debug "Triggering session-lens behaviour since cwd_change_handling feature is disabled"
      M.functions.AutoSaveSession()

      local buffers = vim.api.nvim_list_bufs()
      for _, bufn in pairs(buffers) do
        if not vim.tbl_contains(M.conf.buftypes_to_ignore, vim.api.nvim_buf_get_option(bufn, "buftype")) then
          vim.cmd("silent bwipeout!" .. bufn)
        end
      end

      vim.cmd "clearjumps"
      M.functions.RestoreSession(type(selection) == "table" and selection.path or selection)
    end
  end, 50)
end

---Source session action
---Source a selected session after doing proper current session saving and cleanup
---@param prompt_bufnr number the telescope prompt bufnr
M.source_session = function(prompt_bufnr)
  local action_state = require "telescope.actions.state"
  local selection = action_state.get_selected_entry()
  source_session(selection, prompt_bufnr)
end

---Delete session action
---Delete a selected session file
---@param prompt_bufnr number the telescope prompt bufnr
M.delete_session = function(prompt_bufnr)
  local action_state = require "telescope.actions.state"
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:delete_selection(function(selection)
    M.functions.DeleteSession(selection.path)
  end)
end

M.alternate_session = function(prompt_bufnr)
  local alternate_session = get_alternate_session()

  if not alternate_session then
    Lib.logger.info "There is no alternate session to navigate to, aborting operation"

    if prompt_bufnr then
      actions.close(prompt_bufnr)
    end

    return
  end

  source_session(alternate_session, prompt_bufnr)
end

--TODO: figure out the whole file placeholder parsing, expanding, escaping issue!!
---ex:
---"/Users/ronnieandrewmagatti/.local/share/nvim/sessions//%Users%ronnieandrewmagatti%Projects%dotfiles.vim",
---"/Users/ronnieandrewmagatti/.local/share/nvim/sessions/%Users%ronnieandrewmagatti%Projects%auto-session.vim"
---"/Users/ronnieandrewmagatti/.local/share/nvim/sessions/\\%Users\\%ronnieandrewmagatti\\%Projects\\%auto-session.vim"

return M
