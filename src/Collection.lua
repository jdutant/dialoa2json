--[[ Collection class
    Create and manipulate a Collection
]]
local file = require('file')
local path = require('pathx') -- extends pandoc.path
local normalizeMeta = require('normalizeMeta')
local prepareMeta = require('prepareMeta')

-- # Collection class

---@class Collection
---@field masterMeta pandoc.Meta
---@field masterFile? string
---@field new fun(self: Collection, filepath?: string):Collection
---@field setMasterFile fun(self: Collection, filepath: string)
---@field importMetaFrom fun(self: Collection, filepath: string, format?: 'markdown'|'yaml')
---@field importFromMaster fun(self: Collection, filepath: string, metadataFiles?: string[])
local Collection = {}

---Create a Collection, optionally importing from filepath
---@param filepath? string path to master file
---@param metadataFiles? string[] paths to metadata files
---@return Collection Collection
function Collection:new(filepath, metadataFiles)
    o = {}
    setmetatable(o,self)
    self.__index = self

    if filepath then
        self:importFromMaster(filepath, metadataFiles)
    else
        self.masterFile = nil
        self.masterMeta = pandoc.Meta{}
    end

    return o

end

---store master file path
---@param filepath string
function Collection:setMasterFile(filepath)
    if not file.exists(filepath) then
        log('ERROR', "Master file "..filepath.." not found.")
        return
    end
    self.masterFile = filepath
end

---Import metadata from a file. Existing keys are replaced.
---@param filepath string
---@param format? 'markdown'|'yaml' default markdown
function Collection:importMetaFrom(filepath, format)
    local success, contents = file.read(filepath)
    if not success then
        log('ERROR', "Cannot read file '"..filepath.."'.")
    end

    if format == 'yaml' then
        contents = '---\n'..contents..'\n---\n'
    end

    local meta = pandoc.read(contents).meta

    for k, v in pairs(meta) do
        self.masterMeta[k] = v
    end

end


---Import metadata from master file and (optionally) metadata files
---@param filepath string
---@param metadataFiles? string[]
function Collection:importFromMaster(filepath, metadataFiles)
    self:setMasterFile(filepath)
    if not self.masterFile then return end

    self.masterMeta = pandoc.Meta{}

    self:importMetaFrom(filepath, 'markdown')

    if metadataFiles then
        for _,fpath in ipairs(metadataFiles) do
            self:importMetaFrom(fpath, 'yaml')
        end
    end

    -- normalize user options
    self.masterMeta = normalizeMeta(self.masterMeta)

    -- prepare metadata (pass, gather, replace)
    self.masterMeta = prepareMeta(self.masterMeta, path.directory(self.masterFile))

end

--- Use this to run command line tests with pandoc lua
-- if arg and arg[0] == debug.getinfo(1, "S").source:sub(2) then

-- else
    
return Collection

-- end
