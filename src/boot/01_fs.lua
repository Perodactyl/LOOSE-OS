-- 01_require
---@diagnostic disable: return-type-mismatch, assign-type-mismatch
do
	local boot_env = get_boot_env()
	if boot_env then
		boot_env.PRINT_PREFIX = "[FS] "
	else
		error("Failed to get boot environment. Is the file being run at boot time?")
	end
	_G.fs = {}
	fs.mountPaths = {
		["/"]= _BOOT_ADDR
	}
	--- The working directory that FS uses.
	--- @see fs
	--- @type string
	fs.wd = "/"
	print("FS Root is ".._BOOT_ADDR)
	---@class file
	---  @field mode FSHandleMode
	---  @field id ID
	---  @field proxy FilesystemProxy
	---  @field handle FSHandle
	_G.file = {}

	--- Returns whether a mode is readable
	--- @param mode FSHandleMode
	--- @return boolean readable
	function file.isModeReadable(mode)
		return string.find(mode,"r") ~= nil
	end
	--- Returns whether a mode is writable.
	--- If exact is true, the "a" flag will not be included.
	--- @param mode FSHandleMode
	--- @param exact? boolean
	--- @return boolean writable
	function file.isModeWritable(mode,exact)
		return string.find(mode,exact and "[wa]" or "w") ~= nil
	end
	--- Returns whether a mode is appendable
	--- @param mode FSHandleMode
	--- @return boolean appendable
	function file.isModeAppendable(mode)
		return string.find(mode,"a") ~= nil
	end
	function file.isModeBinary(mode)
		return string.find(mode,"b") ~= nil
	end

	--- Returns whether a file can be read.
	--- To make a file readable, add "r" to the mode when opening. Note that a file cannot be RW or RA.
	--- @see fs.open
	--- @param self file The file to check
	--- @return boolean
	function file.canRead(self)
		local mode = self.mode
		return string.find(mode,"r") ~= nil
	end
	--- Returns whether a file can be written to.
	--- To make a file writable, add "w" or "a" to the mode when opening. Note that a file cannot be RW or RA.
	--- @see fs.open
	--- @param self file The file to check
	--- @param exact? boolean If true, the "a" flag will not be included.
	--- @return boolean
	function file.canWrite(self,exact)
		local mode = self.mode
		return string.find(mode,exact and "[wa]" or "w") ~= nil
	end

	--- Returns whether a file can be appended to.
	--- To make a file appendable, add "a" to the mode when opening. Note that a file cannot be RW or RA.
	--- @see fs.open
	--- @param self file The file to check
	--- @return boolean
	function file.canAppend(self)
		local mode = self.mode
		return string.find(mode,"a") ~= nil
	end

	--- Returns whether a mode string is valid.
	--- @see fs.open
	--- @param mode FSHandleMode
	--- @return boolean
	function file.isValidMode(mode)
		return mode == "r" or mode == "rb" or mode == "w" or mode == "wb" or mode == "a" or mode == "ab"
	end

	function file.read(self,length)
		if not self:canRead() then
			return nil,"File is not readable"
		end
		local component = self.proxy
		local handle = self.handle

		local bytes = 0 --The number of bytes read so far
		local data = "" --The data that has been read
		while bytes < length do
			local block = component.read(handle,math.min(2048,length-bytes))
			if block ~= nil then
				bytes = bytes + #block
				data = data .. block
			elseif bytes == 0 then
				return nil
			else
				break
			end
		end
		return data
	end

	--- Writes data to an open file.
	--- @see fs.open
	--- @param self file The targeted file
	--- @param data string The data to write
	--- @return boolean success,string? why If the write completed successfully and if it didn't, why
	function file.write(self,data)
		if not self:canWrite() then
			return false,"File is not writable"
		end
		local component = self.proxy
		local handle = self.handle
		if component.spaceTotal() - component.spaceUsed() < #data then
			return false,"Not enough disk space in fs "..self.id.." ("..#data.." > "..component.spaceTotal()-component.spaceUsed()..")"
		end

		local blocks = {}
		local block = ""
		for i = 1,#data do
			local char = data:sub(i,i)
			block = block .. char
			if #block >= 2048 then
				component.write(handle,block)
			end
		end
		if #block > 0 then
			component.write(handle,block)
		end
		return true
	end

	--- Closes an open file. This will invalidate self.
	--- @see fs.open
	--- @param self file
	function file.close(self)
		local component,handle = self.proxy,self.handle
		component.close(handle)
		for k,v in pairs(self) do
			if type(v) == "function" then
				self[k] = function(...)
					print("File is closed.")
					return nil,"File is closed."
				end
			end
		end
	end

	--- Returns the path that specifies what drive
	--- @param path string
	--- @return string|nil
	function fs.getMountSection(path)
		if path:sub(1,1) ~= "/" then
			path = "/"..path
		end
		local options = {}
		for name,id in pairs(fs.mountPaths) do
			if path:sub(1,#name) == name then
				table.insert(options,name)
			end
		end
		if #options == 1 then
			return options[1]
		else
			local longest = ""
			for i,opt in ipairs(options) do
				if #opt > #longest then
					longest = opt
				end
			end
			if #longest <= 0 then
				return nil
			end
			return longest
		end
	end

	--- Gets a proxy to the filesystem that a path originates from
	--- @param path string
	--- @return FilesystemProxy|nil result
	function fs.getProxyOf(path)
		path = string.gsub(path,"^%.%/",fs.wd)
		local mount = fs.getMountSection(path)
		if not mount then
			return nil
		end
		local id = fs.mountPaths[mount]
		if not id then
			return nil
		end
		return component.proxy(id)
	end

	--- Gets the path of a file in its mounted drive
	--- @param path string
	--- @return string|nil relativePath
	function fs.getPathOf(path)
		path = string.gsub(path,"^%.%/",fs.wd)
		local mount = fs.getMountSection(path)
		local notMount = path:sub(#mount)
		return notMount
	end

	local function details(path)
		return fs.getProxyOf(path),fs.getPathOf(path)
	end

	--- Returns whether a file exists.
	--- If the path is not valid, it will return a reason.
	--- @param path string
	--- @return boolean,string|nil
	function fs.exists(path)
		path = string.gsub(path,"^%.%/",fs.wd)
		local component,loc = details(path)
		if not component then
			return false,"Filesystem could not be found"
		end
		if not loc then
			return false,"Path could not be found"
		end
		return component.exists(loc)
	end

	--- Opens a file.
	--- @param path string
	--- @param mode? FSHandleMode
	--- @return file|nil result, string? why
	function fs.open(path,mode)
		path = string.gsub(path,"^%.%/",fs.wd)
		if not mode then
			mode = "r"
		end
		if not file.isModeWritable(mode or "r") and not fs.exists(path) then
			return nil,"Cannot open a nonexistent file for read"
		end
		local component = fs.getProxyOf(path)
		local loc = fs.getPathOf(path)
		if not loc then
			return nil,"Failed to get path"
		end
		if component then
			local handle = component.open(loc,mode)
			local result = {
				id= component.address,
				proxy= component,
				handle= handle,
				mode= mode or "r"
			}
			-- setmetatable(result,file_mt)
			for k,v in pairs(file) do
				if type(result[k]) == "nil" then
					result[k] = v
				end
			end
			return result
		else
			return nil,"Path is not mounted"
		end
	end

	print("Locating drives...")
	for id,type in component.list("filesystem") do
		--- @type FilesystemProxy
		local mntPath = "/mnt/"..id:sub(1,8)
		print("Mount "..id.." @ "..mntPath)
		fs.mountPaths[mntPath] = id
	end
	print("Done!")
end