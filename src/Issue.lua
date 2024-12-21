--[[ Issue class

    Hold and manipulate an issue, based on a Collection

    Collections are more abstract: collection of documents with individual settings.
    Issues are more specific: author metadata, etc. 
]]
local stringify = pandoc.utils.stringify
local log = require('log')
--local file = require('file')
--local path = require('pathx') -- extends pandoc.path
local scholarlyMetadata = require('scholarlyMetadata')

-- # Helper functions

---Find first year in metadata value as string
---@param metaDate pandoc.MetaValue
---@return string?
local function getYear(metaDate)
    local year = stringify(metaDate):match('%d%d%d%d')
    return year
end

---parse master metadata into an issue table
---@param meta pandoc.Meta
---@return table
local function parseIssue(meta)
    local tbl = {}

    local maps = {}
    maps.doi = { 
        source = {'doi'},
        destination = {'doi'},
        format = stringify,
    }
    maps.description = { 
        source = {'description'},
        destination = {'description'},
        format = stringify,
    }
    maps.volume = {
        source = {'volume'},
        destination = { 'identification', 'volume' },
        format = stringify,
    }
    maps.number = {
        source = {'issue'},
        destination = { 'identification', 'number' },
        format = stringify,
    }
    maps.year = {
        source = {'date'},
        destination = { 'identification', 'year' },
        format = getYear
    }

    -- integrity check
    local mapsError = nil
    for k, map in pairs(maps) do
        if type(map.source) ~= 'table' or type(map.destination) ~= 'table'
            or type(map.format) ~= 'function' then
                mapsError = 'key '..k..' badly formatted.'
                break
        end
        if #map.source == 0 or #map.destination == 0 then
            mapsError = 'key '..k..' badly formatted.'
            break
        end
    end
    if mapsError then
        log('ERROR', 'Issue data extrator incorrectly defined: '..mapsError)
        return tbl
    end

    local function copyListFromIndex(userList, index)
        local result = {}
        if index > #userList or #userList == 0 then
            return {}
        end
        for i = index, #userList do
            table.insert(result, userList[i])
        end
        return result
    end
        
    local function getValue(userTable, keyList)
        local key = keyList[1]
        if #keyList == 1 then
            return userTable[key]
        else
            if userTable[key] ~= nil then
                getValue(userTable[key], copyListFromIndex(keyList, 2))
            else
                return nil
            end
        end
    end

    local function insertValue(userTable, keyList, value)
        if #keyList == 0 then print('empty keylist!!') return end
        local key = keyList[1]
        if #keyList == 1 then
            userTable[key] = value
            return
        else
            if userTable[key] == nil then
                userTable[key] = {}
            end
            insertValue(userTable[key], copyListFromIndex(keyList, 2), value)
        end
    end

    for _, map in pairs(maps) do
        local value = getValue(meta, map.source)
        if value ~= nil then
            value = map.format(value)
            if value ~= nil then
                insertValue(tbl, map.destination, value)
            end
        end
    end

    return tbl
end

---@class Issue
---@field new fun(self: Issue, collection: Collection, job: Job):Issue
---@field applyScholarlyMetadata fun(self: Issue)
---@field rawJason fun(self:Issue):string
local Issue = {}

---Create an issue object based on collection and job
---@param collection Collection
---@param job Job
---@return Issue o
function Issue:new(collection, job)
    o = {}
    setmetatable(o,self)
    self.__index = self

    self.meta = collection.masterMeta
    self:applyScholarlyMetadata()

    return o
end

---Apply scholarlyMetadata to self.meta
---@return pandoc.Meta
function Issue:applyScholarlyMetadata()
    local meta = self.meta or pandoc.Meta{}
    if meta.imports then
        for _,item in ipairs(meta.imports) do
            if item.meta then
                item.meta = scholarlyMetadata(item.meta)
            end
        end
        self.meta = meta
    end
end
function Issue:getIssue()
    self.issue = self.issue or parseIssue(self.meta)
    return self.issue
end

---Return issue raw metadata as JSON
---@return string json JSON representation of self.meta
function Issue:rawJSON()
    return pandoc.json.encode(self.meta)
end

return Issue
