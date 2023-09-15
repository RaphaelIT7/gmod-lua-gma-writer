# gmod-lua-gma-writer  
This project allows one to write a .gma file with Lua.  

Example:  
```lua  
-- addons/gma is the addon folder I want to turn into a GMA.
GMA.Create("example.txt", "addons/gma", true, false, function(path)
	local worked, files = game.MountGMA(path)
	print(worked)
	PrintTable(files)
end)
```  

NOTE: This doesn't check if any file is whitelisted or not.
