local M = {}

local error = vim.log.levels.ERROR
local trace = vim.log.levels.TRACE
local expand = vim.fn.expand
local fn = vim.fn
local cmd = vim.cmd

local function leaveVisualMode()
	-- https://github.com/neovim/neovim/issues/17735#issuecomment-1068525617
	local escKey = vim.api.nvim_replace_termcodes("<Esc>", false, true, true)
	vim.api.nvim_feedkeys(escKey, "nx", false)
end

--------------------------------------------------------------------------------

---Performing common file operation tasks
---@param op string rename|duplicate|new|newFromSel
local function fileOp(op)
	local dir = expand("%:p:h")
	local oldName = expand("%:t")
	local oldExt = expand("%:e")
  if oldExt ~= "" then
    oldExt = "." .. oldExt
  end
	local prevReg
	if op == "newFromSel" then
		prevReg = fn.getreg("z")
		leaveVisualMode()
		cmd [['<,'>delete z]]
	end

	local promptStr
	if op == "duplicate" then promptStr = "Duplicate File as: "
	elseif op == "rename" then promptStr = "Rename File to: "
	elseif op == "new" or op == "newFromSel" then promptStr = "Name for New File: "
	end

	vim.ui.input({prompt = promptStr}, function(newName)
		local invalidName = false
		if newName then
			invalidName = newName:find("^%s*$") or newName:find("/") or newName:find(":") or newName:find("\\")
		end
		if not (newName) or invalidName then -- cancel
			if op == "newFromSel" then
				cmd [[undo]] -- undo deletion
				fn.setreg("z", prevReg) -- restore register content
			end
			if invalidName then vim.notify(" Invalid Filename.", error) end
			return
		end

		local extProvided = newName:find(".%.") -- non-leading dot to exclude dotfile-dots
		if not (extProvided) then
			newName = newName .. oldExt
		end
		local filepath = dir .. "/" .. newName

		cmd[[update]] -- save current file; needed for people using `vim.opt.hidden=false`
		if op == "duplicate" then
			cmd{cmd = "saveas", args = {filepath}}
			cmd{cmd = "edit", args = {filepath}}
			vim.notify(" Duplicated '" .. oldName .. "' as '" .. newName .. "'.")
		elseif op == "rename" then
			os.rename(oldName, newName)
			cmd{cmd = "edit", args = {filepath}}
			cmd("bdelete #")
			vim.notify(" Renamed '" .. oldName .. "' to '" .. newName .. "'.")
		elseif op == "new" or op == "newFromSel" then
			cmd{cmd = "edit", args = {filepath}}
			if op == "newFromSel" then
				cmd("put z")
				fn.setreg("z", prevReg) -- restore register content
			end
			cmd{cmd = "write", args = {filepath}}
		end
	end)
end

---Rename Current File
function M.renameFile() fileOp("rename") end

---Duplicate Current File
function M.duplicateFile() fileOp("duplicate") end

---Create New File
function M.createNewFile() fileOp("new") end

---Move Selection to New File
function M.moveSelectionToNewFile() fileOp("newFromSel") end

--------------------------------------------------------------------------------

---copying file information
---@param operation string filename|filepath
local function copyOp(operation)
	local reg = '"'
	local clipboardOpt = vim.opt.clipboard:get();
	local useSystemClipb = #clipboardOpt > 0 and clipboardOpt[1]:find("unnamed")
	if useSystemClipb then reg = "+" end

	local toCopy = expand("%:p")
	if operation == "filename" then toCopy = expand("%:t") end

	fn.setreg(reg, toCopy)
	vim.notify(" COPIED\n " .. toCopy)
end

---Copy absolute path of current file
function M.copyFilepath() copyOp("filepath") end

---Copy name of current file
function M.copyFilename() copyOp("filename") end

--------------------------------------------------------------------------------

---Makes current file executable
function M.chmodx()
  local filename = vim.fn.expand('%')
  local perm = vim.fn.getfperm(filename)
  local res = ''
  local r
  for j = 1, perm:len() do
    local char = perm:sub(j, j)
    if j % 3 == 1 then
      r = char == 'r'
    end
    if j % 3 == 0 and r then
      char = 'x'
    end
    res = res .. char
  end
  vim.fn.setfperm(filename, res)
end

---Trash the Current File. Requires `mv`.
---@param opts? table
function M.trashFile(opts)
	if not (opts) then opts = {trashLocation = "$HOME/.Trash/"} end

	local currentFile = expand("%:p")
	local filename = expand("%:t")
	cmd [[update!]]
	os.execute('mv -f "' .. currentFile .. '" "' .. opts.trashLocation .. '"')
	cmd [[bdelete]]
	vim.notify(" '" .. filename .. "' deleted. ")
end

return M
