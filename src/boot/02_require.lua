--02_require
---@diagnostic disable: assign-type-mismatch,deprecated
do
	local boot_env = get_boot_env()
	if boot_env then
		boot_env.PRINT_PREFIX = "[REQUIRE] "
	else
		error("Failed to get boot environment. Is the file being run at boot time?")
	end

	package = nil
	_G.package = {
		path= {},
		loaded= {}
	}

	if not fs.exists("/src/.require") then
		if boot_env.TERM_LEVEL > 1 then
			warn("WARNING: .require file is missing!")
			warn(".require is a core file, it lists paths that files are to be located at.")
			warn("File will be set to default.")
			warn("---")
		else
			print("WARNING: .require file is missing!")
			print(".require is a core file, it lists paths that files are to be located at.")
			print("File will be set to default.")
			print("---")
		end
		local reqpath,why = fs.open("/src/.require","w")
		if reqpath then
			reqpath:write("./?.lua;/src/lib/?.lua;/lib/?.lua;/install/lib/?.lua;/usr/lib/?.lua;/home/lib/?.lua;./?/init.lua;/lib/?/init.lua;/install/lib/?/init.lua;/usr/lib/?/init.lua;/home/lib/?/init.lua;/src/lib/?/init.lua;")
		else
			if boot_env.TERM_LEVEL > 1 then
				warn("Cannot access /src/.require for writing.")
				warn(why or "(Unknown error)")
			else
				print("Cannot access /src/.require for writing.")
				print(why or "(Unknown error)")
			end
		end
	end
	local reqpath = fs.open("/src/.require","r"):read(math.huge)
	if reqpath then
		local current_targ = ""
		for i = 1,#reqpath do
			local char = reqpath:sub(i,i)
			if char == "\n" or char == ";" then
				--- @diagnostic disable-next-line: param-type-mismatch
				table.insert(package.path,current_targ)
				print("Adding "..current_targ.." to package.path")
				current_targ = ""
			else
				current_targ = current_targ .. char
			end
		end
		if #current_targ > 0 then
			--- @diagnostic disable-next-line: param-type-mismatch
			table.insert(package.path,current_targ)
			print("Adding "..current_targ.." to package.path")
		end
	end

	function _G.require(modname)
		if type(package.loaded[modname]) ~= nil then
			return package.loaded[modname]
		end
		local result = ""
		--- @diagnostic disable-next-line: param-type-mismatch
		for i,targ in ipairs(package.path) do
			local mark = string.find(targ,"?")
			if not mark then
				if boot_env.TERM_LEVEL > 1 then
					warn("WARNING: Invalid require path, no '?'")
				else
					print("WARNING: Invalid require path, no '?'")
				end
			else
				local match = string.gsub(targ,"%?",modname)
				if fs.exists(result) then
					result = match
				end
				break
			end
		end
		if not result then
			return nil,"Module not found"
		end
		print(result)
		return result
	end
end