local file = require('file')

---@class Job
---@field source string filepath to the issue master file
---@field metadataFiles table? metadata files (yaml) to import in master file
---@field issue boolean export the issue
---@field items number[] articles to export, by number
local Job = {}

---Create a Job object
---@param source string filepath for the master file
---@param issue? boolean whether to export the whole issue
---@param items? number[] items to export, by number
---@return Job?
function Job:new(source, issue, items)
    o = {}
    setmetatable(o,self)
    self.__index = self

    if not file.exists(source) then
        log('ERROR', 'File '..args.source..' not found.')
        return nil
    end
    self.source = source
    self.metadataFiles = {}

    if items then
        self:addItems(items)
    else
        self.items = {}
    end

    if issue or #self.items == 0 then
        self.issue = true
    end

    return o
end

---add numbered items to a job
---@param items number[]
function Job:addItems(items)
    local result = self.items or {}
    for _,v in ipairs(items) do
        if tonumber(v) then
            table.insert(result, tonumber(v))
        else
            log('WARNING', 'Option -a should be followed by a number.')
        end
    end
    self.items = result
end

function Job:addMetadataFiles(filepaths)
    local result = self.metadataFiles or {}
    for _,fpath in ipairs(filepaths) do
        if not file.exists(fpath) then
            log('WARNING', 'Metadata file '..fpath..' not found.')
        else
            table.insert(result, fpath)
        end
    end
    if #result > 0 then
        self.metadataFiles = result
    end
end

return Job


