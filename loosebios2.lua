--The LOOSE BIOS is able to boot LOOSE OS.
--For some reason, it can't boot anything else.
--And nothing else can boot LOOSE OS.
--I need to fix that.

--When minifying the file, we suggest removing some directives so that it fits in 4KB. We recommend baking the directives (remove all of them except the ones you need, then use them directly in the code.)

--This code is available under the GNU GPLv3 license. <https://www.gnu.org/licenses/gpl-3.0.en.html>
--In addition, any minified version of this code is under the same license. It is required to contain the above line.

---@diagnostic disable: assign-type-mismatch
do
	_G._BIOSVERSION  = "Loose BIOS v0.2.1"
	_G._BIOS_VERSION = "Loose BIOS v0.2.1"
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
	write("Loose BIOS v0.2.1")
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
	---Adds `arg` to the current buffer.
	---@param arg string The line to add.
	function dvs.buf(arg)
		buf = buf .. arg .. "\n"
	end
	---Executes the data in the buffer as lua.
	function dvs.run()
		dvs.lua(buf)
	end
	---Clears the buffer.
	function dvs.clear()
		buf = ""
	end
	---Runs a line of lua.
	---@param code string The line of code to run. Note that `local` values will not be available in later `lua` directives.
	function dvs.lua(code)
		local err,reason = pcall(function()
			load(code)()
		end)
		if err then
			err("Error executing lua: "..code)
			err(reason)
		end
	end
	---Adds a file to the search list.
	---***
	---When booting, Loose BIOS looks for files in the searchlist. If any are found, the drive is considered bootable. The found path is the file to be run.
	---@param arg string The path to add.
	function dvs.addf(arg)
		table.insert(files,arg)
	end
	---Removes a file from the search list.
	---@param arg string The path to remove.
	---@see dvs.addf
	function dvs.remf(arg)
		for i,v in pairs(files) do
			if v == arg then
				table.remove(files,i)
				break
			end
		end
	end
	---Searches for bootable filesystems and adds them to the list of options. Uses the searchlist.
	---@param quiet string|boolean If `"true"` or `true`, does not log to the output.
	---@see dvs.addf
	function dvs.search(quiet)
		if type(quiet) == "string" then
			quiet = quiet == "true"
		end
		if not quiet then
			print("Searching filesystems...")
			print(" |ID"..((" "):rep(35)).."|CTL|Bootable"..((" "):rep(37)).."|")
		end
		for fs in component.list("filesystem") do
			local p = component.proxy(fs)
			if not quiet then
				color(blu)
				write("  "..fs.."  ")
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
			end
			if p then
				local path = nil
				for i,file in ipairs(files) do
					if p.exists(file) then
						if not quiet then
							color(grn)
							write("Y: ")
							color(cyn)
							print(file)
						end
						path = file
						break
					end
				end
				if not path and not quiet then
					color(red)
					print("N")
				elseif path then
					table.insert(options,{fs,path})
				end
			elseif not quiet then
				color(yel)
				print("UNKNOWN FS")
			end
		end
		if not quiet then
			color(std)
		end
	end
	local fsID = nil
	local path = nil
	---Sets the id of an FS to add to the searchlist manually.
	---If both necessary paramaters are present, adds the filesystem.
	---@param arg string The ID of a filesystem.
	---@see dvs.path
	---@see dvs.addf
	function dvs.fs(arg)
		fsID = arg
		if fsID and path then
			table.insert(options,{fsID,path})
			fsID = nil
			path = nil
		end
	end
	---Sets the path to an FS to add to the searchlist manually.
	---If both necessary paramaters are present, adds the filesystem.
	---@param arg string The path of a bootable file in a filesystem.
	---@see dvs.fs
	---@see dvs.addf
	function dvs.path(arg)
		path = arg
		if fsID and path then
			table.insert(options,{fsID,path})
			fsID = nil
			path = nil
		end
	end
	---Boots the given index into the option list.
	---@param arg string|number|nil The index into the option list.
	function dvs.boot(arg) -- Boot option no
		arg = tonumber(arg)
		if not arg then
			arg = 1
		end
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
	---Allows the user to choose which bootable filesystem to boot.
	---If only one FS is present, boots it.
	---Requires a gpu,screen,and keyboard otherwise. The gpu is the only item explicitly checked for.
	function dvs.choose(search) -- List options for usr to choose from
		if #options == 1 then
			print("Only one option to choose from, booting...")
			dvs.boot("1")
			return
		end
		local success,why = pcall(function()
			if not gpu then
				print("No GPU")
				return
			end
			print("Selecting boot source...")
			local selection = 1
			local root = y-1
			local prevLineCount = 0
			local lastSearch = computer.uptime()
			local exit = false
			while not exit do
				local lines = {}
				table.insert(lines,{0xffffff,0x000000,"Select boot source:"})
				for i,data in pairs(options) do
					local id,filename = table.unpack(data)
					if i == selection then
						if gpu.getDepth() > 1 then
							gpu.setBackground(0xAAAAAA)
							gpu.setForeground(0x111111)
						elseif gpu then
							gpu.setBackground(0xFFFFFF)
							gpu.setForeground(0x000000)
						end
					else
						gpu.setBackground(0x000000)
						gpu.setForeground(0xFFFFFF)
					end
					---@type FilesystemProxy
					local component = component.proxy(id)
					if component then
						local rwMode = "RW"
						if component.isReadOnly() then
							rwMode = "RO"
						end
						table.insert(lines,{gpu.getForeground(),gpu.getBackground(),"("..rwMode..") "..id..": "..filename})
					else
						table.insert(lines,{gpu.getForeground(),gpu.getBackground(),"(??) "..id..": (COMPONENT MISSING)"})
					end
				end
				for i = 1,math.max(#lines,prevLineCount) do
					if i <= #lines then
						local fg,bg,line = table.unpack(lines[i])
						local spacing = (" "):rep(w-#line)
						gpu.setForeground(fg)
						gpu.setBackground(bg)
						gpu.set(1,root+i,line)
					else
						gpu.setBackground(0x000000)
						gpu.set(1,root+i,(" "):rep(w))
					end
				end
				prevLineCount = #lines
				while true do
					local event = { computer.pullSignal() }
					if event[1] ~= nil then
						local component_event = event[1] == "component_added" or event[1] == "component_removed"
						if component_event and search == "true" and event[3] == "filesystem" then
							options = {}
							dvs.search("true")
						end
						if event[1] == "key_down" then
							local _,_,_,keycode,_ = table.unpack(event)
							if keycode == 200 or keycode == 17 then --up or w
								selection = selection-1
							elseif keycode == 208 or keycode == 31 then --down or s
								selection = selection+1
							elseif keycode == 57 or keycode == 28 then --enter or space
								print("Booted option #"..selection.."( disk id "..options[selection][1]..", file "..options[selection][2]..")")
								dvs.boot(tostring(selection))
								exit = true
								break
							end
						end
						break
					end
				end
			end
		end)
		if not success then
			color(yel)
			print("Disk selector crashed.")
			print("This may be a result of removing a disk.")
			print("The system will now reboot.")
			local start = computer.uptime()
			computer.pushSignal("tick_pause")
			computer.pullSignal()
			while computer.uptime() - start < 1 do end
			computer.shutdown(true)
		end
	end

	---Parses a string into a list of directives and runs each.
	---Each directive must be the name of a function in `dvs`.
	---Everything after the first word(chunk seperated by a space) is passed in as an argument to the function.
	---@param code string The code to parse. Seperated by newlines or semicolons.
	---@see dvs
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
	dvs.search("true")
	dvs.choose("true")
	-- dvs.parse("search;boot1")

	computer.pullSignal(1)
	warn("\nWARN: Loose BIOS reached end of execution thread")
	while true do coroutine.yield() end
end