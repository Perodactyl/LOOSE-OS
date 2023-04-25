-- Base conversion system, v0.1 -->
-- By: Perodactyl ---------------->
do
	local base = {}

	--- A table that maps numbers to bytes. Note that it is zero-indexed.
	base.conversionTable = {
		[0]="0",
		"1","2","3","4","5","6","7","8","9",
		"a","b","c","d","e","f","g",
		"h","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","A","B","C","D",
		"E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
		"-",
		"_",
		"\1",   "\2","\3","\4","\5","\6","\7","\8","\9","\10","\11","\12","\13","\14","\15","\16",
		"\17","\18","\19","\20","\21","\22","\23","\24","\25","\26","\27","\28","\29","\30","\31",
		" ","!","\"","#","$","%","&","'","(",")","*","+",",",
		-- "-" is already used
		".","/",
		-- 0-9 are taken
		":",";","<","=",">","?","@",
		-- A-Z are taken
		"[","\\","]","^",
		-- "_" is taken
		"`",
		-- a-z are taken
		"{","|","}","~",
		"\128","\129","\130","\131","\132","\133","\134","\135","\136","\137","\138","\139","\140","\141","\142","\143",
		"\144","\145","\146","\147","\148","\149","\150","\151","\152","\153","\154","\155","\156","\157","\158","\159",
		"\160","\161","\162","\163","\164","\165","\166","\167","\168","\169","\170","\171","\172","\173","\174","\175",
		"\176","\177","\178","\179","\180","\181","\182","\183","\184","\185","\186","\187","\188","\189","\190","\191",
		"\192","\193","\194","\195","\196","\197","\198","\199","\200","\201","\202","\203","\204","\205","\206","\207",
		"\208","\209","\210","\211","\212","\213","\214","\215","\216","\217","\218","\219","\220","\221","\222","\223",
		"\224","\225","\226","\227","\228","\229","\230","\231","\232","\233","\234","\235","\236","\237","\238","\239",
		"\240","\241","\242","\243","\244","\245","\246","\247","\248","\249","\250","\251","\252","\253","\254","\255",
	}

	--- Converts a number to a string. The string is in the specified radix.
	--- @param number integer The number to convert
	--- @param radix integer The radix(base) to convert to. Must be between 2 and the length of the conversion table (default 255)
	--- @return string data
	function base.toRadix(number,radix)
		local out = ""
		while number > 0 do
			local section = number % radix
			out = base.conversionTable[section] .. out
			number = math.floor(number / radix)
		end
		if #out == 0 then
			out = base.conversionTable[0]
		end
		return out
	end

	--- Converts a string back to a number. The string is in the specified radix.
	--- @param data string The data to convert
	--- @param radix integer The radix(base) to convert from. Must be between 2 and the length of the conversion table (default 255)
	--- @return integer number
	function base.fromRadix(data,radix)
		local out = 0
		for i = 1,#data do
			local char = data:sub(i,i)
			local code = 0
			for charcode,j in pairs(base.conversionTable) do
				if j == char then
					code = charcode
					break
				end
			end
			out = out * radix
			out = out + code
		end
		
		return out
	end

	return base
end