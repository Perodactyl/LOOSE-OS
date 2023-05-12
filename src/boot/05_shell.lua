--05_shell

--This code is available under the GNU GPLv3 license. <https://www.gnu.org/licenses/gpl-3.0.en.html>

---@diagnostic disable: deprecated
do
	local boot_env = get_boot_env()
	if boot_env then
		boot_env.PRINT_PREFIX = "[SHELL] "
	else
		error("Failed to get boot environment. Is the file being run at boot time?")
	end

	print("Declaring shell...")
	local shell = {
		path= {}
	}

	local searched = {}
	local toSearch = {}

	local function add(line)
		line = string.trim(line)
		if line:sub(1,1) == "@" then
			table.insert(toSearch,line:sub(2,-1))
			print("\t\tDeclared "..line:sub(2,-1).." for later search")
		elseif line:sub(1,1) == "#" then
			print("\tSkipped comment")
		else
			table.insert(shell.path,line)
			print("\tAdding "..line.." to PATH")
		end
	end

	local function search(targetFile)
		if table.includes(searched,targetFile) then
			if boot_env.TERM_LEVEL > 1 then
				warn("WARNING: Circular PATH file loop detected!")
				warn("Skipping file: "..targetFile)
			else
				print("WARNING: Circular PATH file loop detected!")
				print("Skipping file: "..targetFile)
			end
			return
		end
		table.insert(searched,targetFile)
		print("Loading "..targetFile.."...")
		if not fs.exists(targetFile) then
			if boot_env.TERM_LEVEL > 1 then
				warn("WARNING: .path file is missing!")
				warn("File will not be loaded.")
				warn("---")
			else
				print("WARNING: .path file is missing!")
				print("File will not be loaded.")
				print("---")
			end
			return
		end
		local pathlist = fs.open(targetFile,"r"):read(math.huge)
		if pathlist then
			local current_targ = ""
			for i = 1,#pathlist do
				local char = pathlist:sub(i,i)
				if char == "\n" or char == ";" then
					add(current_targ)
					current_targ = ""
				else
					current_targ = current_targ .. char
				end
			end
			if #current_targ > 0 then
				add(current_targ)
			end
		end
	end
	shell.interpretPATHFile = search
	search("/src/.path")
	while #toSearch > 0 do
		search(toSearch[1])
		table.remove(toSearch,1)
	end

	print("Added "..#shell.path.." term(s).")
	print("Searched "..#searched.." file(s).")

	function shell.reload()
		shell.path = {}
		search("/src/.path")
	end

	function shell.findPathOf(cmd)
		local result = ""
		for i,targ in ipairs(shell.path) do
			local mark = string.find(targ,"?")
			if not mark then
				if boot_env.TERM_LEVEL > 1 then
					warn("WARNING: Invalid require path, no '?'")
				else
					print("WARNING: Invalid require path, no '?'")
				end
			else
				local match = string.gsub(targ,"%?",cmd)
				if fs.exists(match) then
					result = match
					break
				end
			end
		end
		if not result then
			return nil
		end
		return result
	end

	function shell.parse(arguments)
		local args = {}
		local options = {}

		local data = type(arguments) == "string" and string.split(string.trim(arguments)," ") or arguments
		local inQuotes = false
		for i,arg in ipairs(args) do
			local startedQuotes = false
			if inQuotes then
				if string.match(arg,"\"$") then
					inQuotes = false
					arg = string.sub(arg,1,-2)
				end
				args[#args] =  args[#args] .. " "..arg
			elseif string.match(arg,"^\"") then
				inQuotes = true
				startedQuotes = true
				table.insert(args,string.sub(arg,2,-1))
			end
			if not startedQuotes then
				local flagPattern = "^[-(--)\\/](.+)"
				if string.match(arg,flagPattern) then
					local iter = string.gmatch(arg,flagPattern)
					iter()
					local flagName = iter()
					if flagName then
						options[flagName] = true
					end
				end
			end
		end

		return args,options
	end

	local input = "test test -abc --test=tre"
	local args,options = shell.parse(input)
	print("Args:")
	print(table.unpack(args))
	print("Ops:")
	print(table.unpack(options))

	function shell.run(command,...)
		local blocks = string.split(command," ")
		local cmd = blocks[1]
		local data = ""
		for i = 2,#blocks do
			if i == 2 then
				data = blocks[i]
			else
				data = data .. " " ..blocks[i]
			end
		end
		local path = shell.findPathOf(cmd)
		if path then
			local file,fileErr = fs.open(path,"r")
			if file then
				local filedata,readErr = file:read(math.huge)
				if filedata == nil then
					return false,"'"..path.."' (origin of command '"..cmd.."') could not be read.",readErr
				end
				local exe,loadErr = load(filedata)
				if (not exe) or loadErr then
					return false,"'"..path.."' (origin of command '"..cmd.."') could not be loaded.",loadErr
				end
				local out = { pcall(exe,...) }
				if not out[1] then
					return false,"'"..path.."' (origin of command '"..cmd.."') could not be executed.",out[2]
				end
				return true,table.unpack(out,2)
			else
				return false,"'"..path.."' (origin of command '"..cmd.."') could not be opened.",fileErr
			end
		else
			return false,"'"..cmd.."' could not be located."
		end
	end

	print("Testing shell.run...")
	shell.run("helloworld")

	_G.shell = shell
	_G.PATH = shell.path
end