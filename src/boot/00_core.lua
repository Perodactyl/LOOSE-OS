--00_core

--This code is available under the GNU GPLv3 license. <https://www.gnu.org/licenses/gpl-3.0.en.html>

---@diagnostic disable: assign-type-mismatch
do
	local fs = _G.CORE_BOOT_FS
	local boot_env = {}
	local boot_env_unlocked = true

	--- Returns the boot_env, which contains data that is only important at boot time.
	--- Once the system is finished booting, the boot_env locks and get_boot_env returns nil.
	function _G.get_boot_env()
		if boot_env_unlocked then
			return boot_env
		end
		return nil
	end
	--- Lists proxies of components with type `type`.
	--- @param type componentType
	--- @return Proxy ...
	function component.find(type)
		local matches = component.list(type)
		local list = {}
		for addr,_ in matches do
			table.insert(list,component.proxy(addr))
		end
		return table.unpack(list)
	end
	--- Returns the first component with type `type`.
	--- @param type componentType
	--- @return Proxy|nil
	function component.find1(type)
		local out = component.find(type) -- By only taking 1 output, this discards any other values.
		return out
	end

	function boot_env.create_gfx_env()
		_G.GFX = false
		---@type ScreenProxy|nil
		local screen = component.find("screen")
		---@type GPUProxy|nil
		local gpu = component.find1("gpu")
		if not screen and not gpu then
			return nil,nil,false,"Missing screen and GPU"
		end
		if not screen then
			return nil,nil,false,"Missing screen"
		end
		if not gpu then
			return nil,nil,false,"Missing GPU"
		end
		gpu.bind(screen.address)
		_G.GFX = not not (screen and gpu)
		_G.GFX_SCREEN = screen
		_G.GFX_GPU = gpu
		_G.GFX_X = 1
		_G.GFX_Y = 1
		_G.GFX_W,_G.GFX_H = gpu.getViewport()
		return screen,gpu,true,nil
	end
	
	local _,_,success,err = boot_env.create_gfx_env()
	if not success then
		error(err)
	end

	---Writes text to the screen.

---@diagnostic disable-next-line: duplicate-set-field
	function _G.write(...)
		if not GFX then
			return false
		end
		local args = {...}
		if #args == 1 then
			local msg = args[1]
			for i = 1,#msg do
				local char = msg:sub(i,i)
				if char == "\n" or GFX_X >= GFX_W then
					GFX_X = 0
					GFX_Y = GFX_Y + 1
				end
				if GFX_Y > GFX_H then
					GFX_Y = GFX_H
					GFX_GPU.copy(1,1,GFX_W,GFX_H,0,-1)
					GFX_GPU.fill(1,GFX_H,GFX_W,1," ")
				end
				GFX_GPU.set(GFX_X,GFX_Y,char)
				GFX_X = GFX_X + 1
			end
		else
			for i,arg in ipairs(args) do
				write(arg)
			end
		end
		return true
	end
	function _G.print(...)
		local values = {}
		for i,text in ipairs({...}) do
			local timestamp = ""
			if boot_env.PRINT_TIMESTAMP then
				local uptime = computer.uptime()
				timestamp = "{"..uptime..((" "):rep(5-#tostring(uptime))).."} "
			end
			table.insert(values,timestamp..boot_env.PRINT_PREFIX..tostring(text).."\n")
		end
		return write(table.unpack(values))
	end

	boot_env.TERM_LEVEL = 1 -- Basic print and write
	boot_env.PRINT_PREFIX = "[CORE] "
	boot_env.PRINT_TIMESTAMP = true

	GFX_GPU.setBackground(0x000000)
	GFX_GPU.fill(1,1,GFX_W,GFX_H," ")

	print("Loose OS Booting...")
	if not _LOOSE then
		GFX_GPU.setForeground(0xFFFF00)
		print("WARNING: It is recommended to boot Loose OS using LOOSE BIOS.")
		GFX_GPU.setForeground(0xFFFFFF)
	end

	local coreColor = 0x00FFFF
	local bootFileColor = 0x0000FF

	GFX_GPU.setForeground(coreColor)

	print("Terminal Level: 1 (Basic print and write functions online)")
	print("Loading substeps...")

	local colorList = {
		0xFF00FF,
		0x00FF00,
		0x0000FF
	}
	local currentColor = 1
	local files = fs.list("/src/boot")
	table.sort(files,function(a,b)
		local stepA = tonumber(a:sub(1,2))
		local stepB = tonumber(b:sub(1,2))
		return stepA < stepB
	end)
	for i,file in ipairs(files) do
		print(file)

		if file == "00_core.lua" then
			print("Bootfile found, skipping...")
		else

			local handle = fs.open("/src/boot/"..file,"r")
			local code = ""
			local blocks = 0
			while true do
				local result = fs.read(handle, 2048)
				if result == nil then
					break
				end
				blocks = blocks + 1
				code = code .. result
			end
			print("Read "..blocks.." block(s) - "..#code.." bytes")
			local exe,why = load(code)
			if not exe then
				print("Error loading "..file..": "..why)
			else
				GFX_GPU.setForeground(colorList[currentColor])
				currentColor = currentColor+1
				if currentColor > #colorList then
					currentColor = 1
				end
				local wasSuccess,errMsg = pcall(exe)
				GFX_GPU.setForeground(coreColor)
				if not wasSuccess then
					boot_env.PRINT_PREFIX = "[ERR] "
					GFX_GPU.setForeground(0xFF0000)
					print("Error running "..file..": ")
					print(errMsg)
					GFX_GPU.setForeground(coreColor)
				end
				boot_env.PRINT_PREFIX = "[CORE] "
			end
		end
	end

	boot_env_unlocked = false
	print("Core locked. get_boot_env will no longer return a value.")
end