GMA = GMA or {}
GMA.Addon = {
	Indent = "GMAD",
	Version = 3,
	AppID = 4000,
	CompressionSignature = 0xBEEFCACE,
	Header = { -- 5 chars
		Ident = "    ", -- 4 chars
		Version = " ",  -- 1 char
	},
	TimestampOffset = 5 + 8 -- Header Size + uint64_t
}
GMA.Queue = GMA.Queue or {}

local str_b0 = string.char(0)
function GMA.Build(output, name, description, path, files, crc, prepared)
	prepared = prepared or {}

	local f = file.Open(output, "wb", "DATA")
	assert(f, "Failed to open " .. output)

	--[[
		Header
	]]
	f:Write(GMA.Addon.Indent) -- Ident (4)
	f:WriteByte(GMA.Addon.Version)  -- Version (1)
	f:WriteUInt64(0) -- SteamID (8) [unused]
	f:WriteUInt64(system.SteamTime()) -- TimeStamp (8)
	f:WriteByte(0) -- Required content (list of strings) [seems unused]
	f:Write(name .. str_b0) -- Addon Name (n)
	f:Write(description .. str_b0) -- Addon Description (n)
	f:Write("Author Name" .. str_b0) -- Addon Author (n) [unused]
	f:WriteLong(1) -- Addon Version (4) [unused]

	--[[
		File list
	]]
	for id, ffile in ipairs(files) do
		local data = prepared[ffile]

		f:WriteLong(id) -- File number (4)

		f:Write(string.lower(string.sub(ffile, #path + 1)) .. str_b0) -- File name (all lower case!) (n)

		f:WriteUInt64(data.size) -- File size (8). We don't have WriteInt64 :<

		-- crc
		if crc then
			f:WriteULong(util.CRC(data.content)) -- File CRC (4)
		else
			f:WriteULong(0)
		end
	end

	f:WriteULong(0)

	--[[
		File content
	]]
	for id, ffile in ipairs(files) do
		f:Write(prepared[ffile].content)
	end

	--[[
		.gma CRC
	]]

	if crc then
		local origin = f:Tell()
		f:Seek(0)
		local CRC = util.CRC(f:Read(f:Size()))
		f:Seek(origin)

		f:WriteULong(CRC)
	else
		f:WriteULong(0)
	end

	f:Close()
end

function GMA.PrePareFiles(tbl, path, files, async)
	async = async or false

	assert(tbl, "Missing table!")

	tbl.done = false
	tbl.files = {}
	tbl.queue = {}
	tbl.checkfile = function(file, status, content, id)
		if status != FSASYNC_OK then
			error("Failed to read " .. file .. " (Code: " .. tostring(status) .. ")")
		end

		tbl.files[file] = {
			content = content, -- file.Read is slow
			size = string.len(content) -- file.Size is slow.
		}

		table.remove(tbl.queue, id)
		if #tbl.queue == 0 then
			tbl.OnFinish(tbl.files)
		end
	end

	for _, ffile in ipairs(files) do
		local id = table.insert(tbl.queue, ffile)
		if async then
			file.AsyncRead(ffile, "GAME", function(_, _, status, content)
				tbl.checkfile(ffile, status, content, id)
			end)
		else
			tbl.checkfile(ffile, FSASYNC_OK, file.Read(ffile, "GAME"), id)
		end
	end
end

function GMA.FindFiles(tbl, path, ignore)
	path = string.EndsWith(path, "/") and path or (path .. "/") 

	local files, folders = file.Find(path .. "*", "GAME")
	for _, file in ipairs(files) do
		--[[
			Ignore addon.json and everything in the ignore table.
		]]
		if file == "addon.json" then continue end
		local skip = false
		for _, str in ipairs(ignore) do
			if string.EndsWith(file, str) then
				skip = true
				break
			end
		end
		if skip then continue end

		table.insert(tbl, path .. file)
	end

	for _, folder in ipairs(folders) do
		GMA.FindFiles(tbl, path .. folder, ignore)
	end
end

function GMA.AddToQueue(tbl, func)
	tbl.func = func
	table.insert(GMA.Queue, tbl)
end

function GMA.Create(output, input, async, crc, callback)
	async = async or false
	crc = crc or false

	input = string.EndsWith(input, "/") and input or (input .. "/")

	local addon = file.Read(input .. "addon.json", "GAME")
	local addon_tbl = util.JSONToTable(addon)
	local description = util.JSONToTable(addon)
	description.title = nil
	description.description = description.description or "Description"
	description.type = string.lower(description.type or "")
	description.ignore = nil

	local files = {}
	GMA.FindFiles(files, input, addon_tbl.ignore)

	local prepare = {}
	prepare.OnFinish = function(prepared)
		GMA.Build(output, addon_tbl.title, "\n"..string.Replace(util.TableToJSON(description, true), '"tags": ', '"tags": \n	'), input, files, crc, prepared)
		callback("data/" .. output)
	end

	GMA.PrePareFiles(prepare, input, files, async)
end

--[[
	Example
]]
GMA.Create("test10.txt", "addons/gma", true, false, function(path)
	local worked, files = game.MountGMA(path)
	print(worked)
	PrintTable(files)
end)