--03_util

--This code is available under the GNU GPLv3 license. <https://www.gnu.org/licenses/gpl-3.0.en.html>

do
	local boot_env = get_boot_env()
	if boot_env then
		boot_env.PRINT_PREFIX = "[UTIL] "
	else
		error("Failed to get boot environment. Is the file being run at boot time?")
	end

	--- Returns a string without whitespace at the start or end.
	--- Note that this does not modify the given string.
	---
	--- From https://stackoverflow.com/questions/10460126/how-to-remove-spaces-from-a-string-in-lua, answer 2 (as of 05/09/2023, MMDDYYYY)
	--- 
	--- Note that this is not a standard lua function.
	--- @param self string The table to search
	--- @return string trimmed A copy of the string without whitespace on either end.
	function string.trim(self)
		return self:match( "^%s*(.-)%s*$" )
	end
	print("Declared string.trim")

	--- Returns a table of sections of the input string, seperated by the delimiter. Does not include the delimiter.
	--- Note that this does not modify the given string.
	--- 
	--- Note that this is not a standard lua function.
	--- @param self string The string to split.
	--- @param delimiter string The delimiter pattern to search by. Defaults to `,%s`, which splits by whitespace or commas.
	--- @return table chunks Sections of the string.
	function string.split(self,delimiter,remove_empty)
		if delimiter == nil then
			delimiter = ",%s"
		end
		if remove_empty == nil then
			remove_empty = true
		end
		local pattern = "[^"..delimiter.."]"
		if not remove_empty then
			pattern = pattern .. "*"
		else
			pattern = pattern .. "+"
		end
		local result = {}
		for token in string.gmatch(self, pattern) do
			table.insert(result,token)
		end
		return result
	end
	print("Declared string.split")

	--- Returns whether a specific value is in a table.
	--- 
	--- Note that this is not a standard lua function.
	--- @param self table The table to search
	--- @param item any The value to search for
	--- @return boolean included Whether the value is somewhere in the table
	function table.includes(self,item)
		for k,v in pairs(self) do
			if v == item then
				return true
			end
		end
		return false
	end
	print("Declared table.includes")
	table.has = table.includes
	print("Declared table.has (an alias of table.includes)")

	local function serialize(data,minify,visited,depth)
		if type(data) == "string" then
			return "\""..data.."\""
		elseif type(data) == "nil" then
			return "nil"
		elseif type(data) == "number" then
			return tostring(data)
		elseif type(data) == "boolean" then
			if data then
				return "true"
			else
				return "false"
			end
		elseif type(data) == "function" then
			return "[Function]"
		else
			if table.includes(visited,data) then
				local name = "(Unknown)"
				for k,v in pairs(visited) do
					if v == data then
						name = k
						break
					end
				end
				return "[Circular Reference: "..name.."]"
			end
			local out = "{\n"
			for k,v in pairs(data) do
				if minify then
					if out:sub(-1,-1) ~= "{" then
						out = out .. ","
					end
				else
					if out:sub(-1,-1) ~= "{" then
						out = out .. ",\n"
					end
				end
				out = out .. ("\t"):rep(depth)
				out = out .. "["
				out = out .. serialize(k,minify,visited,depth+1)
				out = out .. "]="
				out = out .. serialize(v,minify,visited,depth+1)

				if type(v) == "table" then
					visited[k] = v
				end
			end
			if minify then
				out = out .. "}"
			else
				out = out .. "\n}"
			end
			return out
		end
	end
	print("Implemented serialize")
	
	--- Returns a stringified version of a table.
	--- 
	--- Note that this is not a standard lua function.
	--- @param self table The table to search
	--- @param mini? boolean If true, the table will have no whitespace.
	--- @return string data The table as a string.
	function table.serialize(self,mini)
		if mini == nil then
			mini = false
		end
		return serialize(self,mini,{},0)
	end
	print("Declared table.serialize")
end