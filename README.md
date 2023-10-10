# gmod-lua-gma-writer  
This project allows one to write a .gma file with Lua.  

Examples:  
```lua  
-- addons/gma is the addon folder I want to turn into a GMA.
GMA.Create("example.txt", "addons/gma", true, false, function(path)
	local worked, files = game.MountGMA(path)
	print(worked)
	PrintTable(files)
end)
```  

```lua  
-- Reads the given GMA file (does not need to end with .GMA) from the data/ folder
PrintTable(GMA.Read("example.txt"))
```

## GMA.Create(Output file, Input folder, Async, CRC, Callback function)  

## GMA.Read(Input file, No Content bool(default = false), path string (default = "DATA")) 

NOTE: This doesn't check if any file is whitelisted or not.
