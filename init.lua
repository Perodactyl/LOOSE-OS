--init.lua
---@diagnostic disable: cast-local-type, assign-type-mismatch
do
	_G.TERM_LEVEL = 0 --No terminal
	_G.PRINT_PREFIX = ""
	_G.PRINT_TIMESTAMP = false
	local boot_addr = nil
	local boot_fn = nil
	if _LOOSE then
		boot_addr = _BOOT_ADDR
		boot_fn = _BOOT_FN
	else
		for i,addr in ipairs(component.list("filesystem")) do
			local fs = component.proxy(addr)
			if fs then
				if fs.exists(".loose_boot") then
					boot_addr = addr
					break
				end
			end
		end
	end
	boot_addr = "55f809f6-d1c3-43b9-b13b-ea1c957fecc3"

	if not boot_addr then
		error("No boot address found.")
	end
	_G._BOOT_ADDR = boot_addr
	---@type FilesystemProxy
	local fs = component.proxy(boot_addr)
	if not fs.exists("/src/boot/00_core.lua") then
		error("Missing core file: /src/boot/00_core.lua")
	end
	local handle = fs.open("/src/boot/00_core.lua","r")
	local code = ""
	while true do
		local result = fs.read(handle, 2048)
		if result == nil then
			break
		end
		code = code .. result
	end
	if type(code) ~= "string" or #code <= 0 then
		error("/src/boot/00_core.lua was not loadable lua.")
	end
	_G.CORE_BOOT_FS = fs
	local exe,why = load(code)
	if exe then
		exe()
	else
		error("Failed to load /src/boot/00_core.lua: "..why)
	end

	while true do
		coroutine.yield()
	end
end