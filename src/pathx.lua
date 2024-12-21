--[[ pathx Extra path functions for Pandoc Lua
]]
local type = pandoc.utils.type
local stringify = pandoc.utils.stringify
local pathx = pandoc.path

---Reads "${.}" paths as relative to basepath, as in Pandoc defaults files.
---@param path string|pandoc.Inline|pandoc.Inlines
---@param basepath string
---@return string
function pathx.readMetaPath(path, basepath)
    local basepath = basepath or ''

    local path = type(path) == 'string' and path
        or (type(path) == 'Inlines' or type(path) == 'Inline') 
            and stringify(path)
        or ''

    path = path:gsub('^%${%.}', basepath)

    return path
end

return pathx