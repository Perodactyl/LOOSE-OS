---@diagnostic disable: assign-type-mismatch
do
	_G._BIOSVERSION  = "Loose BIOS v0.2"
	_G._BIOS_VERSION = "Loose BIOS v0.2"
	--- All things logged while LOOSE BIOS was in control.
	--- @type string|nil
	_G._LOOSE_LOG = ""
	--- Shows that LOOSE BIOS is running. LOOSE BIOS provides several utilities that make it easier for startup code to run.
	--- @type true|nil
	_G._LOOSE = true
	--- The address of the filesystem that the LOOSE BIOS booted from.
	--- @type string|nil
	_G._BOOT_ADDR = ""
	--- Abbreviation. Gets the first valid component of type `t`.
	--- @param t componentType The type of component to find
	--- @return table|nil
	local function getC(t)
		local id = component.list(t)()
		if id ~= nil then
			return component.proxy(id)
		else
			return nil
		end
	end
	--- @type ScreenProxy GPUProxy EEPROMProxy
	---@type ScreenProxy|nil
	local screen = getC("screen")
	---@type GPUProxy|nil
	local gpu = getC("gpu")
	---@type EEPROMProxy
	local eeprom = getC("eeprom")

	eeprom.setLabel(_G._BIOS_VERSION)

	-- I wish I didn't need to implement these, but they are needed for OpenOS to boot.

---@diagnostic disable-next-line: duplicate-set-field
	function _G.computer.getBootAddress()
		if not eeprom then
			return nil
		end
		return eeprom.getData()
	end
---@diagnostic disable-next-line: duplicate-set-field
	function _G.computer.setBootAddress(addr)
		if eeprom then
			eeprom.setData(addr)
		end
	end

	local x,y,w,h
	if screen ~= nil and gpu ~= nil then
		gpu.bind(screen.address)
		x,y,w,h = 1,1,gpu.getViewport()
	end
	local function scroll()
		if gpu then
			gpu.copy(1,1,w,h,0,-1)
			gpu.fill(1,h-1,w,1," ")
		end
	end
	local function write(data)
		_LOOSE_LOG = _LOOSE_LOG .. data
		if not gpu then
			return
		end
		for i = 1,#data do
			local char = data:sub(i,i)
			if x >= w or char == "\n" then
				x = 0
				y = y + 1
			end
			if y >= h or char == "\v" then
				y = h-1
				scroll()
			end
			gpu.set(x,y,char)
			x = x + 1
		end
	end
	local function print(data)
		write(tostring(data).."\n")
	end
	local function fill(x,y,w,h,c)
		if gpu then
			gpu.fill(x,y,w,h,c)
		end
	end
	local function color(color)
		if gpu and gpu.getDepth() > 1 then
			gpu.setForeground(color)
		end
	end
	local std = 0xFFFFFF
	local red = 0xFF0000
	local grn = 0x00FF00
	local blu = 0x0000FF
	local cyn = 0x00FFFF
	local mag = 0xFF00FF
	local yel = 0xFFFF00
	local function warn(msg)
		color(yel)
		print(msg)
		color(std)
	end
	local function err(msg)
		color(red)
		print(msg)
		color(std)
	end
	
	_G._LOOSE_WRITE = write
	_G._LOOSE_PRINT = print
	_G._LOOSE_WARN = warn
	_G._LOOSE_ERR = err
	
	fill(1,1,w,h," ")
	print("Size: "..w..", "..h)
	write("-- ")
	color(red)
	write("Loose BIOS v0.2")
	color(std)
	print(" --")
	local dvs = {} --directives
	local bootPath = nil
	local buf = ""
	local files = {
		"/init.lua",
		"/startup.lua",
		"/boot/init.lua",
		"/boot/startup.lua",
		"/autorun.lua"
	}
	local options = {}

	local function boot(code,errMsg)
		if type(code) ~= "string" or #code <= 0 then
			err(errMsg)
			err("Invalid Bootcode ("..type(code).."): "..tostring(code))
			return
		end
		---@diagnostic disable-next-line: redundant-parameter
		-- computer.pullSignal(1)
		local exe,why = load(code,"Bootcode","bt",_G)
		if not exe then
			err("Failed to load bootcode")
			err(errMsg)
			err(why)
			return
		end
		-- exe()
		_G.BOOT_FN = boot
		-- xpcall(exe,function(reason,...)
		-- 	err("Failed to execute bootcode")
		-- 	err(errMsg)
		-- 	err(reason)
		-- 	local varargs = {...}
		-- 	if #varargs > 0 then
		-- 		warn("Writing varargs:")
		-- 		for i,v in ipairs(varargs) do
		-- 			write(i..". ")
		-- 			print(tostring(v))
		-- 		end
		-- 	end
		-- end);
		local error, reason = pcall(exe)
		if error then
			err("Failed to execute bootcode")
			err(errMsg)
			err(reason)
		end
	end
	function dvs.buf(arg)
		buf = buf .. arg .. "\n"
	end
	function dvs.run()
		dvs.lua(buf)
		buf = ""
	end
	function dvs.lua(code)
		local err,reason = pcall(function()
			load(code)()
		end)
		if err then
			err("Error executing lua: "..code)
			err(reason)
		end
	end
	function dvs.addf(arg)
		table.insert(files,arg)
	end
	function dvs.remf(arg)
		for i,v in pairs(files) do
			if v == arg then
				table.remove(files,i)
				break
			end
		end
	end
	function dvs.search()
		print("Searching filesystems...")
		print(" |ID"..((" "):rep(35)).."|CTL|Bootable"..((" "):rep(37)).."|")
		for fs in component.list("filesystem") do
			color(blu)
			write("  "..fs.."  ")
			local p = component.proxy(fs)
			if p and p.isReadOnly() then
				color(red)
				write("RO  ")
			elseif p then
				color(grn)
				write("RW  ")
			else
				color(mag)
				write("??  ")
			end
			if p then
				local path = nil
				for i,file in ipairs(files) do
					if p.exists(file) then
						color(grn)
						write("Y: ")
						color(cyn)
						print(file)
						path = file
						break
					end
				end
				if not path then
					color(red)
					print("N")
				else
					table.insert(options,{fs,path})
				end
			else
				color(yel)
				print("UNKNOWN FS")
			end
		end
		color(std)
	end
	local fsID = nil
	local path = nil
	function dvs.fs(arg)
		fsID = arg
		if fsID and path then
			table.insert(options,{fsID,path})
		end
	end
	function dvs.path(arg)
		path = arg
		if fsID and path then
			table.insert(options,{fsID,path})
		end
	end
	function dvs.boot(arg) -- Boot option no
		arg = tonumber(arg)
		if arg > #options or arg < 1 then
			warn("WARN: Option out of bounds (1,"..#options.."): "..arg)
			return
		end
		local id,file = table.unpack(options[arg])
		local descriptor = id..file
		_G._BOOT_ADDR = id
		color(yel)
		write("Booting ")
		color(mag)
		write(id)
		color(cyn)
		print(file)
		local fs = component.proxy(id)
		if not fs then
			warn("WARN: Invalid FS of id: "..id)
			return
		end
		local handle = fs.open(file,"r")
		local code = ""
		local code = ""
		while true do
			local result = fs.read(handle, 2048)
			if result == nil then
				break
			end
			code = code .. result
		end
		fs.close(handle)
		boot(code,"Crashed when running code from "..descriptor)
	end
	function dvs.choose() -- List options for usr to choose from
		if #options == 1 then
			dvs.boot("1")
		end
	end

	---@param code string
	function dvs.parse(code)
		if type(code) ~= "string" then
			err("Failed to parse directives: Not a string ("..type(code).."): "..tostring(code))
			return
		end
		local lines = {}
		local curLine = ""
		for i = 1,#code do
			local char = code:sub(i,i)
			if char == "\n" or char == ";" then
				table.insert(lines,curLine)
				curLine = ""
			else
				curLine = curLine .. char
			end
		end
		if #curLine > 0 then
			table.insert(lines,curLine)
		end
		for i,line in ipairs(lines) do
			for name,fn in pairs(dvs) do
				if string.find(line,name) then
					local start,stop = string.find(line,name)
					if stop ~= nil then
						local arg = line:sub(stop+1, -1)
						fn(arg)
						-- print("---")
						-- print(name)
						-- print(arg)
					else
						-- print("---")
						-- print(name)
						fn()
					end
					break
				end
			end
		end
	end

	-- Put user directives here
	dvs.search()
	dvs.boot("1")
	-- dvs.parse("search;boot1")

	computer.pullSignal(1)
	warn("\nWARN: Loose BIOS reached end of execution thread")
	while true do coroutine.yield() end
end