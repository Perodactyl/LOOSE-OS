-- Data
-- By Perodactyl (MC username Perodactus)

--This code is available under the GNU GPLv3 license. <https://www.gnu.org/licenses/gpl-3.0.en.html>

--- Implements functions of a datacard. Will fall back to an available datacard.
--- Note that performance will likely be impacted if a datacard of the required tier isn't present.

--- This entire file practically just pulls together other people's lua cryptography code.

do
	local crypto = {} --Custom implementations
	local data = {} --Wrapper of DataCardProxy

	do

		-- SHA-256
		-- By KillaVanilla
		-- Adapted by Perodactyl
		-- Original:
		--  https://pastebin.com/9c1h7812

		local bit = bit32

		local k = {
			0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
			0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
			0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
			0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
			0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
			0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
			0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
			0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
		}
		local function generateShiftBitmask(bits)
			local bitmask = 0
		for i=1, bits do
			bit.bor(bitmask, 0x8000000)
			bit.rshift(bitmask, 1)
		end
		return bitmask
		end
 
		local function Preprocessing(message)
			local len = #message*8
			local bits = #message*8
			table.insert(message, 1)
			while true do
				if bits % 512 == 448 then
					break
				else
					table.insert(message, 0)
					bits = #message*8
				end
			end
			table.insert(message, len)
			return message
		end
		local function breakMsg(message)
			local chunks = {}
			local chunk = 1
			for word=1, #message, 16 do
				chunks[chunk] = {}
				table.insert(chunks[chunk], message[word] or 0)
				table.insert(chunks[chunk], message[word+1] or 0)
				table.insert(chunks[chunk], message[word+2] or 0)
				table.insert(chunks[chunk], message[word+3] or 0)
				table.insert(chunks[chunk], message[word+4] or 0)
				table.insert(chunks[chunk], message[word+5] or 0)
				table.insert(chunks[chunk], message[word+6] or 0)
				table.insert(chunks[chunk], message[word+7] or 0)
				table.insert(chunks[chunk], message[word+8] or 0)
				table.insert(chunks[chunk], message[word+9] or 0)
				table.insert(chunks[chunk], message[word+10] or 0)
				table.insert(chunks[chunk], message[word+11] or 0)
				table.insert(chunks[chunk], message[word+12] or 0)
				table.insert(chunks[chunk], message[word+13] or 0)
				table.insert(chunks[chunk], message[word+14] or 0)
				table.insert(chunks[chunk], message[word+15] or 0)
				chunk = chunk+1
			end
			return chunks
		end
		local function digestChunk(chunk, hash)
			for i=17, 64 do
				local s0 = bit.bxor( bit.rshift(chunk[i-15], 3), bit.bxor( bit.rrotate(chunk[i-15], 7), bit.rrotate(chunk[i-15], 18) ) )
				local s1 = bit.bxor( bit.rshift(chunk[i-2], 10), bit.bxor( bit.rrotate(chunk[i-2], 17), bit.rrotate(chunk[i-2], 19) ) )
				chunk[i] = (chunk[i-16] + s0 + chunk[i-7] + s1) % (2^32)
			end
			local a = hash[1]
	 		local b = hash[2]
	 		local c = hash[3]
	 		local d = hash[4]
	 		local e = hash[5]
	 		local f = hash[6]
	 		local g = hash[7]
	 		local h = hash[8]
			for i=1, 64 do
				local S1 = bit.bxor(bit.rrotate(e, 6), bit.bxor(bit.rrotate(e,11),bit.rrotate(e,25)))
				local ch = bit.bxor( bit.band(e, f), bit.band(bit.bnot(e), g) )
				local t1 = h + S1 + ch + k[i] + chunk[i]
				--d = d+h
				S0 = bit.bxor(bit.rrotate(a,2), bit.bxor(bit.rrotate(a,13),bit.rrotate(a,22) ))
				local maj = bit.bxor( bit.band( a, bit.bxor(b, c) ), bit.band(b, c) )
				local t2 = S0 + maj
				h = g
				g = f
				f = e
				e = d + t1
				d = c
				c = b
				b = a
				a = t1 + t2
				a = a % (2^32)
				b = b % (2^32)
				c = c % (2^32)
				d = d % (2^32)
				e = e % (2^32)
				f = f % (2^32)
				g = g % (2^32)
				h = h % (2^32)
			end
			hash[1] = (hash[1] + a) % (2^32)
			hash[2] = (hash[2] + b) % (2^32)
			hash[3] = (hash[3] + c) % (2^32)
			hash[4] = (hash[4] + d) % (2^32)
			hash[5] = (hash[5] + e) % (2^32)
			hash[6] = (hash[6] + f) % (2^32)
			hash[7] = (hash[7] + g) % (2^32)
			hash[8] = (hash[8] + h) % (2^32) 
			return hash
		end
 
		local function digest(msg)
			msg = Preprocessing(msg)
			local hash = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19}
			local chunks = breakMsg(msg)
			for i=1, #chunks do
				hash = digestChunk(chunks[i], hash)
			end
			return hash
		end
		
		local function digestStr(input)
			-- transform the input into a table of ints:
			local output = {}
			local outputStr = ""
			for i=1, #input do
				output[i] = string.byte(input, i, i)
			end
			output = digest(output)
			for i=1, #output do
				outputStr = outputStr..string.format("%X", output[i])
			end
			return outputStr, output
		end
		
		local function hashToBytes(hash)
			local bytes = {}
			for i=1, 8 do
				table.insert(bytes, bit.band(bit.rshift(bit.band(hash[i], 0xFF000000), 24), 0xFF))
				table.insert(bytes, bit.band(bit.rshift(bit.band(hash[i], 0xFF0000), 16), 0xFF))
				table.insert(bytes, bit.band(bit.rshift(bit.band(hash[i], 0xFF00), 8), 0xFF))
				table.insert(bytes, bit.band(hash[i], 0xFF))
			end
			return bytes
		end
		
		local function hmac(input, key)
			-- HMAC(H,K,m) = H( (K <xor> opad) .. H((K <xor> ipad) .. m))
			-- Where:
			-- H - cryptographic hash function. In this case, H is SHA-256.
			-- K - The secret key.
			--	if length(K) > 256 bits or 32 bytes, then K = H(K)
			--  if length(K) < 256 bits or 32 bytes, then pad K to the right with zeroes. (i.e pad(K) = K .. repeat(0, 32 - byte_length(K)))
			-- m - The message to be authenticated.
			-- .. - byte concentration
			-- <xor> eXclusive OR.
			-- opad - Outer Padding, equal to repeat(0x5C, 32).
			-- ipad - Inner Padding, equal to repeat(0x36, 32).
			if #key > 32 then
				local keyDigest = digest(key)
				key = keyDigest
			elseif #key < 32 then
				for i=#key, 32 do
					key[i] = 0
				end
			end
			local opad = {}
			local ipad = {}
			for i=1, 32 do
				opad[i] = bit.bxor(0x5C, key[i] or 0)
				ipad[i] = bit.bxor(0x36, key[i] or 0)
			end
			local padded_key = {}
			for i=1, #input do
				ipad[32+i] = input[i]
			end
			local ipadHash = hashToBytes(digest(ipad))
			ipad = ipadHash
			for i=1, 32 do
				padded_key[i] = opad[i]
				padded_key[32+i] = ipad[i]
			end
			return digest(padded_key)
		end
		crypto.sha256 = digestStr
	end

	do
		--[[

		base64 -- v1.5.3 public domain Lua base64 encoder/decoder
		no warranty implied; use at your own risk

		Modified by Perodactyl.
		Original:
		https://github.com/iskolbin/lbase64/

		Original license is MIT or Public Domain. I think that makes it so I don't need any legal stuff ever.
		This modification is also Public Domain. (www.unlicense.org)

		--]]


		local base64 = {}

		local extract = _G.bit32 and _G.bit32.extract -- Lua 5.2/Lua 5.3 in compatibility mode

		function base64.makeencoder( s62, s63, spad )
			local encoder = {}
			for b64code, char in pairs{[0]='A','B','C','D','E','F','G','H','I','J',
				'K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y',
				'Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n',
				'o','p','q','r','s','t','u','v','w','x','y','z','0','1','2',
				'3','4','5','6','7','8','9',s62 or '+',s63 or'/',spad or'='} do
				encoder[b64code] = char:byte()
			end
			return encoder
		end

		function base64.makedecoder( s62, s63, spad )
			local decoder = {}
			for b64code, charcode in pairs( base64.makeencoder( s62, s63, spad )) do
				decoder[charcode] = b64code
			end
			return decoder
		end

		local DEFAULT_ENCODER = base64.makeencoder()
		local DEFAULT_DECODER = base64.makedecoder()

		local char, concat = string.char, table.concat

		function base64.encode( str, encoder, usecaching )
			encoder = encoder or DEFAULT_ENCODER
			local t, k, n = {}, 1, #str
			local lastn = n % 3
			local cache = {}
			for i = 1, n-lastn, 3 do
				local a, b, c = str:byte( i, i+2 )
				local v = a*0x10000 + b*0x100 + c
				local s
				if usecaching then
					s = cache[v]
					if not s then
						s = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[extract(v,0,6)])
						cache[v] = s
					end
				else
					s = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[extract(v,0,6)])
				end
				t[k] = s
				k = k + 1
			end
			if lastn == 2 then
				local a, b = str:byte( n-1, n )
				local v = a*0x10000 + b*0x100
				t[k] = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[64])
			elseif lastn == 1 then
				local v = str:byte( n )*0x10000
				t[k] = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[64], encoder[64])
			end
			return concat( t )
		end

		function base64.decode( b64, decoder, usecaching )
			decoder = decoder or DEFAULT_DECODER
			local pattern = '[^%w%+%/%=]'
			if decoder then
				local s62, s63
				for charcode, b64code in pairs( decoder ) do
					if b64code == 62 then s62 = charcode
					elseif b64code == 63 then s63 = charcode
					end
				end
				pattern = ('[^%%w%%%s%%%s%%=]'):format( char(s62), char(s63) )
			end
			b64 = b64:gsub( pattern, '' )
			local cache = usecaching and {}
			local t, k = {}, 1
			local n = #b64
			local padding = b64:sub(-2) == '==' and 2 or b64:sub(-1) == '=' and 1 or 0
			for i = 1, padding > 0 and n-4 or n, 4 do
				local a, b, c, d = b64:byte( i, i+3 )
				local s
				if usecaching then
					local v0 = a*0x1000000 + b*0x10000 + c*0x100 + d
					s = cache[v0]
					if not s then
						local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
						s = char( extract(v,16,8), extract(v,8,8), extract(v,0,8))
						cache[v0] = s
					end
				else
					local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
					s = char( extract(v,16,8), extract(v,8,8), extract(v,0,8))
				end
				t[k] = s
				k = k + 1
			end
			if padding == 1 then
				local a, b, c = b64:byte( n-3, n-1 )
				local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40
				t[k] = char( extract(v,16,8), extract(v,8,8))
			elseif padding == 2 then
				local a, b = b64:byte( n-3, n-2 )
				local v = decoder[a]*0x40000 + decoder[b]*0x1000
				t[k] = char( extract(v,16,8))
			end
			return concat( t )
		end
		crypto.decode64 = base64.decode
		crypto.encode64 = base64.encode
	end

	function crypto.crc32(data)
		
	end

	function data.maxPhysicalCard()
		local cards = component.list("data")
		local max = 0
		local card = nil
		for cardID in cards do
			local oldMax = max
			--- @type DataCardProxy
			local comp = component.proxy(cardID)
			if comp.crc32 ~= nil then
				max = math.max(max,1)
				if max > oldMax then
					card = comp
				end
			end
			if comp.encrypt ~= nil then
				max = math.max(max,2)
				if max > oldMax then
					card = comp
				end
			end
			if comp.generateKeyPair ~= nil then
				max = math.max(max,3)
				if max > oldMax then
					card = comp
				end
			end
		end
		return max,card
	end

	function data.getLimit()
		local level,card = data.maxPhysicalCard()
		if level > 0 then
			return card.getLimit()
		end
		return math.huge
	end

	function data.crc32(msg)
		local level,card = data.maxPhysicalCard()
		if level < 1 then
			return crypto.crc32(msg)
		else
			return card.crc32(msg)
		end
	end

	function data.decode64(msg)
		local level,card = data.maxPhysicalCard()
		if level < 1 then
			return crypto.encode64(msg)
		else
			return card.encode64(msg)
		end
	end

	function data.encode64(msg)
		local level,card = data.maxPhysicalCard()
		if level < 1 then
			return crypto.encode64(msg)
		else
			return card.encode64(msg)
		end
	end

	function data.md5(msg)
		local level,card = data.maxPhysicalCard()
		if level < 1 then
			return crypto.md5(msg)
		else
			return card.md5(msg)
		end
	end

	function data.sha256(msg)
		local level,card = data.maxPhysicalCard()
		if level < 1 then
			return crypto.sha256(msg)
		else
			return card.sha256(msg)
		end
	end

	function data.deflate(msg)
		local level,card = data.maxPhysicalCard()
		if level < 1 then
			return crypto.deflate(msg)
		else
			return card.deflate(msg)
		end
	end

	function data.inflate(msg)
		local level,card = data.maxPhysicalCard()
		if level < 1 then
			return crypto.inflate(msg)
		else
			return card.inflate(msg)
		end
	end

	return data
end