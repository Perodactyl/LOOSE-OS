--A system that implements bitmap drawing functions.
--Not fully implemented yet.
--By Perodactus. See the README for more info.

--This code is available under the GNU GPLv3 license. <https://www.gnu.org/licenses/gpl-3.0.en.html>

do
	local half = "▄"

	--- A mode used for rendering.
	--- half: Uses half of a character for rendering, creating a 1:1 resolution. Default.
	--- double: Uses two characters for rendering, creating a 1:1 resolution.
	--- stretch: Uses 1 character for rendering, creating a 2:1 resolution. Not recommended.
	---@alias RenderMode "half" | "double" | "stretch"
	--- A mode for coordinate indexing.
	--- zeroIndex: Coordinates are (0-(w-1),0-(h-1)). Non-standard for lua. Default.
	--- oneIndex: Coordinates are (1-w,1-h). Standard for lua. Less common due to strange math.
	---@alias IndexingMode "zeroIndex" | "oneIndex"
	---@class Context
	--- @field proxy GPUProxy
	--- @field width integer
	--- @field height integer
	--- @field trueW integer
	--- @field trueH integer
	--- @field mode RenderMode
	--- @field indexMode IndexingMode

	---@class Context
	local Context = {}
	local lib = {}

	---Converts a number in the given mode into zeroIndex.
	--- @param value number
	--- @param indexingMode IndexingMode
	--- @return number zeroIndexed
	local function toZeroIndex(value,indexingMode)
		if indexingMode == "zeroIndex" then
			return value
		else
			return value - 1
		end
	end

	--- Sets the screen size of a context. This changes the width and height. Some data may be truncated.
	--- @param w integer
	--- @param h integer
	function Context.setScreenSize(self,w,h)
		self.trueW = w
		self.trueH = h
		self:calculateSize(true)
	end

	--- Calculates width and height of a context from the screen size.
	--- @param force? boolean If false, may return a previous result without recalculation.
	function Context.calculateSize(self,force)
		if not force then
			if self.width and self.height then
				return self.width,self.height
			end
		end
		if not self.width and not self.height then
			local charW,charH = self.trueW,self.trueH
			
			if self.mode == "stretch" then --Pixels are 1*1 characters. (1:2)
				self.width = charW
				self.height = charH
			elseif self.mode == "double" then --Pixels are 2*1 double characters. (1:1)
				self.width = charW
				self.height = math.floor(charH / 2)
			else --Pixels are 1*1/2 half characters. (1:1). Recommended and default mode.
				self.width = charW
				self.height = charH * 2
			end
		elseif (not self.width) or (not self.height) then
			if not self.width then
				self.width = self.height
			elseif not self.height then
				self.height = self.width
			end
		end

		return self.width, self.height
	end

	--- Returns the width and height of a context.
	function Context.resolution(self)
		return self:calculateSize()
	end

	--- Changes the mode of a context.
	---
	--- If you are going to change the resolution and mode of a context at the same time, we suggest changing them and then calling `context:calculateSize(true)`
	--- @param mode RenderMode The mode to switch to.
	function Context.setMode(self,mode)
		self.mode = mode
		self:calculateSize(true)
	end

	function Context.set(self,x,y,color,usePalette)
		local w,h = self.resolution()
		x = toZeroIndex(x,self.indexMode)
		y = toZeroIndex(y,self.indexMode)
		w = toZeroIndex(w,self.indexMode)
		h = toZeroIndex(h,self.indexMode)
		local err = ""
		if x < 0 or y < 0 or x >= w or y >= h then
			err = "Coordinate Error: "
			local errData = {}
			table.insert(errData,"Note that all values are zero-indexed.")
			table.insert(errData,"X: "..x)
			table.insert(errData,"Y: "..y)
			if x < 0 then
				table.insert(errData,"X out of bounds (before screen)")
			end
			if y < 0 then
				table.insert(errData,"y out of bounds (before screen)")
			end
			if x > w then
				table.insert(errData,"x out of bounds (after screen)")
			end
			if y > h then
				table.insert(errData,"y out of bounds (after screen)")
			end
			err = err .. table.concat(errData,", ")
			return nil,error
		end
		if self.mode == "half" then
			local charY = math.floor(y/2) --Character Y coordinate
			local realY = y % 2 --Half-character
			local char,fg,bg = self.proxy.get(x+1,charY+1)
			if char ~= half then
				Context.proxy.set(x+1,charY+1,half)
				fg = 0x000000
				bg = 0x000000
			end
			if realY == 0 then
				Context.proxy.setForeground(fg)
				Context.proxy.setBackground(color,usePalette)
			else
				Context.proxy.setForeground(color,usePalette)
				Context.proxy.setBackground(bg)
			end
			Context.proxy.set(x+1,charY+1,half)
		elseif self.mode == "double" then
			local charX = x * 2
			Context.proxy.setBackground(color,usePalette)
			Context.proxy.set(charX  ,y," ")
			Context.proxy.set(charX+1,y," ")
		else
			Context.proxy.setBackground(color,usePalette)
			Context.proxy.set(x,y," ")
		end
	end

	function lib.getContext(screen)
		if type(screen) == "string" then
			screen = component.proxy(component.get(screen))
		end
		if type(screen) == "nil" then
			screen = component.gpu
		end
		if screen == nil then
			return nil,"Could not get a valid screen"
		end
		local context = {
			proxy= screen
		}
		return context
	end

	return lib
end