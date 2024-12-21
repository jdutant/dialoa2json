
---------------------------------------------------------
----------------Auto generated code block----------------
---------------------------------------------------------

do
    local searchers = package.searchers or package.loaders
    local origin_seacher = searchers[2]
    searchers[2] = function(path)
        local files =
        {
------------------------
-- Modules part begin --
------------------------

["prepareMeta"] = function()
--------------------
-- Module: 'prepareMeta'
--------------------
--[[ prepareMeta.lua prepare metadata: gather, globalize and pass.
]]

local type = pandoc.utils.type
local stringify = pandoc.utils.stringify
local log = require('log')
local file = require('file')
local path = require('pathx')

-- # Collection functions
local setup = {
    gather = nil,
    replace = nil,
    pass = nil,
    globalize = nil,
}

---Gather or replace selected master metadata based on import files metadata.
--Keys to be gathered or replaced are listed in `setup.gather` and
--`setup.replace`. Gathering (used for header-includes, bibliographies): if a
-- key preexists we make a list with the old and new values; if both are lists
-- we merge them. Replacing: if a key preexists we replace it with the source's
-- values; if present in different sources, the last one prevails. Useful in
-- offprint mode (single source) or for keys that don't overlap across sources.
-- If a key is set to be gathered and replaced, it will be replaced.
---@param meta pandoc.Meta
---@return pandoc.Meta
local function gather_and_replace(meta)

    ---process Metadata import items, insert values in meta.imports[i].meta
    ---@param item pandoc.MetaMap|pandoc.MetaInlines|pandoc.MetaInline|string
    local function process(item)
        -- read and parse the file
        local filepath = path.readMetaPath(item.file)
        local success, contents = file.read(filepath)
        if not success then
            log('ERROR', 'Cannot read file '..filepath..'.')
            return
        end
        item.meta = pandoc.read(contents).meta

        -- for each key to gather, import in the master metadata if it exist
        -- merging behaviour:
        --  if the preexisting is a list, we append
        --  if the preexisting key has a value, we turn into
        --      a list and we append
        if setup.gather then 
            for _,key in ipairs(setup.gather) do
                if item.meta[key] then
                    if not meta[key] then
                        meta[key] = item.meta[key]:clone()
                    else
                        if type(meta[key]) ~= 'List' then
                            meta[key] = pandoc.MetaList(meta[key])
                        end
                        if type(item.meta[key]) == 'List' then
                            meta[key]:extend(item.meta[key])
                        else
                            meta[key]:insert(item.meta[key])
                        end
                    end
                end
            end
        end

        -- for each key to replace, we import it in the document's meta
        if setup.replace then
            for _,key in ipairs(setup.replace) do
                if item.meta[key] then
                    meta[key] = item.meta[key]
                end
            end
        end

        return item
    end

    for _,item in ipairs(meta.imports) do
        -- we know `item` is a MetaMap, but not if it has a `file` key
        -- if it doesn't we skip it
        if item.file then
            item = process(item)
        end
    end

    return meta
end

---Globalize selected metadata fields into the master key `global-metadata` and
---place selected filed into the master key `child-medata`. The first will be 
---present in root and all descendants, the latter in children only. Preexisting
---keys in `global-metadata` and `child-metadata` are replaced.
---@param meta pandoc.Meta
---@return pandoc.Meta
local function globalize_and_pass(meta)
    -- mapping `setup` keys with `meta` keys
    local map = { 
        globalize = 'global-metadata',
        pass = 'child-metadata'
    }
    for setupkey, metakey in pairs(map) do
        -- are there `setup.globalize` or `setup.pass` keys?
        if setup[setupkey] then 
            for _,key in ipairs(setup[setupkey]) do
                -- is there a `key` field in metadata to copy?
                if meta[key] then
                    if meta[metakey] and meta[metakey][key] then
                        log('WARNING', 
                        'Metadata: '..setupkey..' `'..key..'` replaced `'..key..
                        '` in `' .. metakey .. '`.')
                    end
                    meta[metakey] = meta[metakey] or pandoc.MetaMap{}
                    meta[metakey][key] = meta[key]
                end
            end
        end
    end
    return meta
end

local function build(meta)
    if not meta.imports then return end
    --child-metadata contents are inserted into import metadata
    --global-metadata key is imported as is
    for i = 1, #meta.imports do
        local item = meta.imports[i]
        if meta['global-metadata'] then
            item.meta = item.meta or pandoc.MetaMap{}
            if item.meta['global-metadata'] then
                log('WARNING', 'Imported file '..i..' global-metadata key is'
                .." replaced by the master's.")
            end
            item.meta['global-metadata'] = meta['global-metadata']
        end
        if meta['child-metadata'] then
            item.meta = item.meta or pandoc.MetaMap{}
            for key, val in pairs(meta['child-metadata']) do
                if item.meta[key] then
                    log('WARNING', 'Imported file '..i..' key `'..key'` is'
                    .." replaced by the master's child-metadata value.")
                end
                item.meta[key] = val
            end
        end
    end
    return meta
end

-- # Main function

---@param meta pandoc.Meta
---@param basepath string path for relative `${.}` paths
---@return pandoc.Meta
local function prepareMeta(meta, basepath)

    -- check meta.imports. do nothing if it doesn't exist, ensure it's a list
    -- otherwise.
    if not meta.imports then
        log('INFO', "No `imports` field in master file, nothing to import.")
        return meta
    elseif type(meta.imports) ~= 'List' then
        meta.imports = pandoc.MetaList(meta.imports)
    end

    -- Ensure each import item is a MetaMap; if not, assume it's a filename. We
    -- change this in the doc itself, in case later filters rely on this field
    -- too. 
    for i = 1, #meta.imports do
        if type(meta.imports[i]) ~= 'table' then
            local filepath = path.readMetaPath(meta.imports[i], basepath)
            meta.imports[i] = pandoc.MetaMap({
                file = pandoc.MetaString(filepath)
            })
        end
    end
    -- NOTE bear in mind some `imports` items may still lack a `file` key
    -- this allows users to deactivate a source without removing its data
    -- by changing `file` to `fileoff` for instance

    -- check that each `file` exists. If not, issue an error message
    -- and turn off the `file` key
    for i = 1, #meta.imports do
        if meta.imports[i].file then
            local filepath = path.readMetaPath(meta.imports[i].file, basepath)
            if filepath == '' then
                meta.imports[i].file = nil -- clean up deficient values
            elseif not file.exists(filepath) then
                log('WARNING', 'File '..filepath..' (import '..i..') not found.)')
                meta.imports[i].fileoff = filepath
                meta.imports[i].file = nil
            end
        end
    end

    -- build lists of metadata keys to gather, globalize and pass
    if meta.collection then
        for _,key in ipairs({'gather','replace', 'globalize', 'pass'}) do
            if meta.collection[key] then
                if type(meta.collection[key]) ~= 'List' then
                    meta.collection[key] = pandoc.MetaList(meta.collection[key])
                end
                setup[key] = pandoc.List:new()
                for _,entry in ipairs(meta.collection[key]) do
                    setup[key]:insert(stringify(entry))
                end
            end
        end
    end

    -- gather and replace main metadata using source files values
    meta = gather_and_replace(meta)

    -- globalize and pass the required metadata keys
    meta = globalize_and_pass(meta)

    -- mimic collection build
    meta = build(meta)

    return meta

end

return prepareMeta
end,

["file"] = function()
--------------------
-- Module: 'file'
--------------------
local system = pandoc.system
local path = pandoc.path

-- ## File module
local file = {}

---Whether a file exists
---@param filepath string
---@return boolean
function file.exists(filepath)
    local filepath = filepath or ''
    local f = io.open(filepath, 'r')
    if f ~= nil then
      io.close(f)
      return true
    else 
      return false
    end  
end

---read file as string (default) or binary.
---@param filepath string file path
---@param mode? 'b'|'t' 'b' for binary or 't' for text (default text)
---@return boolean success
---@return string? contents file contents if success
function file.read(filepath, mode)
    local mode = mode == 'b' and 'rb' or 'r'
    local contents
    local f = io.open(filepath, mode)
    if f then 
        contents = f:read('a')
        f:close()
        return true, contents
    else
        return false
    end
end

---Write string to file in text or binary mode.
---@param contents string file contents
---@param filepath string file path
---@param mode? 'b'|'t' 'b' for binary or 't' for text (default text)
---@return boolean success
function file.write(contents, filepath, mode)
    local mode = mode == 'b' and 'wb' or 'w'
    local f = io.open(filepath, mode)
      if f then 
        f:write(contents)
        f:close()
        return true
    else
      return false
    end
end

return file
end,

["normalizeMeta"] = function()
--------------------
-- Module: 'normalizeMeta'
--------------------
--[[ normalizeMeta: Normalize metadata options for collection
]]
local log = require('log')
local type = pandoc.utils.type
local stringify = pandoc.utils.stringify

--- syntactic_sugar: normalize alias keys in meta
-- in case of duplicates we warn the user and
-- use the ones with more explicit names.
-- if `collection` or `offprints` are strings
-- we assume they're defaults filepaths.
local function normalizeMeta(meta)

    -- function that converts aliases to official fields in a map
    -- following an alias table. 
    -- The map could be the doc's Meta or a MetaMap within it. 
    -- Use `root` to let the user know what the root key was in the 
    -- later case in error messages, e.g. "imports[1]/". 
    -- Merging behaviour: if the official already exists we warn the
    -- user and simply ignore the alias key.
    -- Warning: aliases must be acceptable Lua map keys, so they can't
    --  contain e.g. dashes. Official names aren't restricted.
    -- @alias_table table an alias map aliasname = officialname. 
    -- @root string names the root for error messages, e.g. "imports[1]/"
    -- @map Meta or MetaMap to be cleaned up
    function make_official(alias_table, root, map)
        if type(map) == 'table' or type(map) == 'Meta' then
            for alias,official in pairs(alias_table) do
                if map[alias] and map[official] then
                    log('WARNING', 'Metadata: `'..root..alias..'` '
                         ..'is a duplicate of `'..root..official..'`, '
                        ..'it will be ignored.')
                    map[alias] = nil
                elseif map[alias] then
                    map[official] = map[alias]
                    map[alias] = nil
                end
            end
        end
        return map
    end

    local aliases = {
        global = 'global-metadata',
        metadata = 'child-metadata',
    }
    meta = make_official(aliases, '', meta)

    if meta.imports and type(meta.imports) == 'List' then 
        local aliases = {
            metadata = 'child-metadata'
        }
        for i = 1, #meta.imports do
            local rt = 'imports[' .. i .. ']/'
            meta.imports[i] = make_official(aliases, rt, meta.imports[i])
        end
    end

    if meta.collection and type(meta.collection) ~= 'table' then
        local filepath = stringify(meta.collection)
        log('INFO', 'Assuming `collection` is a defaults file ' 
            .. 'filepath: ' .. filepath .. '.' )
        meta.collection = pandoc.MetaMap({
            defaults = filepath
        })
    end

    if meta.offprints and type(meta.offprints) ~= 'table' then
        local filepath = stringify(meta.offprints)
        log('INFO', 'Assuming `offprints` is a defaults file ' 
            .. 'filepath: ' .. filepath .. '.' )
        meta.offprints = pandoc.MetaMap({
            defaults = filepath
        })
    end

    return meta
end

return normalizeMeta
end,

["Issue"] = function()
--------------------
-- Module: 'Issue'
--------------------
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

end,

["argparse"] = function()
--------------------
-- Module: 'argparse'
--------------------
-- The MIT License (MIT)

-- Copyright (c) 2013 - 2018 Peter Melnichenko

-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
-- the Software, and to permit persons to whom the Software is furnished to do so,
-- subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
-- FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
-- COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
-- IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

local function deep_update(t1, t2)
   for k, v in pairs(t2) do
      if type(v) == "table" then
         v = deep_update({}, v)
      end

      t1[k] = v
   end

   return t1
end

-- A property is a tuple {name, callback}.
-- properties.args is number of properties that can be set as arguments
-- when calling an object.
local function class(prototype, properties, parent)
   -- Class is the metatable of its instances.
   local cl = {}
   cl.__index = cl

   if parent then
      cl.__prototype = deep_update(deep_update({}, parent.__prototype), prototype)
   else
      cl.__prototype = prototype
   end

   if properties then
      local names = {}

      -- Create setter methods and fill set of property names.
      for _, property in ipairs(properties) do
         local name, callback = property[1], property[2]

         cl[name] = function(self, value)
            if not callback(self, value) then
               self["_" .. name] = value
            end

            return self
         end

         names[name] = true
      end

      function cl.__call(self, ...)
         -- When calling an object, if the first argument is a table,
         -- interpret keys as property names, else delegate arguments
         -- to corresponding setters in order.
         if type((...)) == "table" then
            for name, value in pairs((...)) do
               if names[name] then
                  self[name](self, value)
               end
            end
         else
            local nargs = select("#", ...)

            for i, property in ipairs(properties) do
               if i > nargs or i > properties.args then
                  break
               end

               local arg = select(i, ...)

               if arg ~= nil then
                  self[property[1]](self, arg)
               end
            end
         end

         return self
      end
   end

   -- If indexing class fails, fallback to its parent.
   local class_metatable = {}
   class_metatable.__index = parent

   function class_metatable.__call(self, ...)
      -- Calling a class returns its instance.
      -- Arguments are delegated to the instance.
      local object = deep_update({}, self.__prototype)
      setmetatable(object, self)
      return object(...)
   end

   return setmetatable(cl, class_metatable)
end

local function typecheck(name, types, value)
   for _, type_ in ipairs(types) do
      if type(value) == type_ then
         return true
      end
   end

   error(("bad property '%s' (%s expected, got %s)"):format(name, table.concat(types, " or "), type(value)))
end

local function typechecked(name, ...)
   local types = {...}
   return {name, function(_, value) typecheck(name, types, value) end}
end

local multiname = {"name", function(self, value)
   typecheck("name", {"string"}, value)

   for alias in value:gmatch("%S+") do
      self._name = self._name or alias
      table.insert(self._aliases, alias)
   end

   -- Do not set _name as with other properties.
   return true
end}

local function parse_boundaries(str)
   if tonumber(str) then
      return tonumber(str), tonumber(str)
   end

   if str == "*" then
      return 0, math.huge
   end

   if str == "+" then
      return 1, math.huge
   end

   if str == "?" then
      return 0, 1
   end

   if str:match "^%d+%-%d+$" then
      local min, max = str:match "^(%d+)%-(%d+)$"
      return tonumber(min), tonumber(max)
   end

   if str:match "^%d+%+$" then
      local min = str:match "^(%d+)%+$"
      return tonumber(min), math.huge
   end
end

local function boundaries(name)
   return {name, function(self, value)
      typecheck(name, {"number", "string"}, value)

      local min, max = parse_boundaries(value)

      if not min then
         error(("bad property '%s'"):format(name))
      end

      self["_min" .. name], self["_max" .. name] = min, max
   end}
end

local actions = {}

local option_action = {"action", function(_, value)
   typecheck("action", {"function", "string"}, value)

   if type(value) == "string" and not actions[value] then
      error(("unknown action '%s'"):format(value))
   end
end}

local option_init = {"init", function(self)
   self._has_init = true
end}

local option_default = {"default", function(self, value)
   if type(value) ~= "string" then
      self._init = value
      self._has_init = true
      return true
   end
end}

local add_help = {"add_help", function(self, value)
   typecheck("add_help", {"boolean", "string", "table"}, value)

   if self._has_help then
      table.remove(self._options)
      self._has_help = false
   end

   if value then
      local help = self:flag()
         :description "Show this help message and exit."
         :action(function()
            print(self:get_help())
            os.exit(0)
         end)

      if value ~= true then
         help = help(value)
      end

      if not help._name then
         help "-h" "--help"
      end

      self._has_help = true
   end
end}

local Parser = class({
   _arguments = {},
   _options = {},
   _commands = {},
   _mutexes = {},
   _groups = {},
   _require_command = true,
   _handle_options = true
}, {
   args = 3,
   typechecked("name", "string"),
   typechecked("description", "string"),
   typechecked("epilog", "string"),
   typechecked("usage", "string"),
   typechecked("help", "string"),
   typechecked("require_command", "boolean"),
   typechecked("handle_options", "boolean"),
   typechecked("action", "function"),
   typechecked("command_target", "string"),
   typechecked("help_vertical_space", "number"),
   typechecked("usage_margin", "number"),
   typechecked("usage_max_width", "number"),
   typechecked("help_usage_margin", "number"),
   typechecked("help_description_margin", "number"),
   typechecked("help_max_width", "number"),
   add_help
})

local Command = class({
   _aliases = {}
}, {
   args = 3,
   multiname,
   typechecked("description", "string"),
   typechecked("epilog", "string"),
   typechecked("target", "string"),
   typechecked("usage", "string"),
   typechecked("help", "string"),
   typechecked("require_command", "boolean"),
   typechecked("handle_options", "boolean"),
   typechecked("action", "function"),
   typechecked("command_target", "string"),
   typechecked("help_vertical_space", "number"),
   typechecked("usage_margin", "number"),
   typechecked("usage_max_width", "number"),
   typechecked("help_usage_margin", "number"),
   typechecked("help_description_margin", "number"),
   typechecked("help_max_width", "number"),
   typechecked("hidden", "boolean"),
   add_help
}, Parser)

local Argument = class({
   _minargs = 1,
   _maxargs = 1,
   _mincount = 1,
   _maxcount = 1,
   _defmode = "unused",
   _show_default = true
}, {
   args = 5,
   typechecked("name", "string"),
   typechecked("description", "string"),
   option_default,
   typechecked("convert", "function", "table"),
   boundaries("args"),
   typechecked("target", "string"),
   typechecked("defmode", "string"),
   typechecked("show_default", "boolean"),
   typechecked("argname", "string", "table"),
   typechecked("hidden", "boolean"),
   option_action,
   option_init
})

local Option = class({
   _aliases = {},
   _mincount = 0,
   _overwrite = true
}, {
   args = 6,
   multiname,
   typechecked("description", "string"),
   option_default,
   typechecked("convert", "function", "table"),
   boundaries("args"),
   boundaries("count"),
   typechecked("target", "string"),
   typechecked("defmode", "string"),
   typechecked("show_default", "boolean"),
   typechecked("overwrite", "boolean"),
   typechecked("argname", "string", "table"),
   typechecked("hidden", "boolean"),
   option_action,
   option_init
}, Argument)

function Parser:_inherit_property(name, default)
   local element = self

   while true do
      local value = element["_" .. name]

      if value ~= nil then
         return value
      end

      if not element._parent then
         return default
      end

      element = element._parent
   end
end

function Argument:_get_argument_list()
   local buf = {}
   local i = 1

   while i <= math.min(self._minargs, 3) do
      local argname = self:_get_argname(i)

      if self._default and self._defmode:find "a" then
         argname = "[" .. argname .. "]"
      end

      table.insert(buf, argname)
      i = i+1
   end

   while i <= math.min(self._maxargs, 3) do
      table.insert(buf, "[" .. self:_get_argname(i) .. "]")
      i = i+1

      if self._maxargs == math.huge then
         break
      end
   end

   if i < self._maxargs then
      table.insert(buf, "...")
   end

   return buf
end

function Argument:_get_usage()
   local usage = table.concat(self:_get_argument_list(), " ")

   if self._default and self._defmode:find "u" then
      if self._maxargs > 1 or (self._minargs == 1 and not self._defmode:find "a") then
         usage = "[" .. usage .. "]"
      end
   end

   return usage
end

function actions.store_true(result, target)
   result[target] = true
end

function actions.store_false(result, target)
   result[target] = false
end

function actions.store(result, target, argument)
   result[target] = argument
end

function actions.count(result, target, _, overwrite)
   if not overwrite then
      result[target] = result[target] + 1
   end
end

function actions.append(result, target, argument, overwrite)
   result[target] = result[target] or {}
   table.insert(result[target], argument)

   if overwrite then
      table.remove(result[target], 1)
   end
end

function actions.concat(result, target, arguments, overwrite)
   if overwrite then
      error("'concat' action can't handle too many invocations")
   end

   result[target] = result[target] or {}

   for _, argument in ipairs(arguments) do
      table.insert(result[target], argument)
   end
end

function Argument:_get_action()
   local action, init

   if self._maxcount == 1 then
      if self._maxargs == 0 then
         action, init = "store_true", nil
      else
         action, init = "store", nil
      end
   else
      if self._maxargs == 0 then
         action, init = "count", 0
      else
         action, init = "append", {}
      end
   end

   if self._action then
      action = self._action
   end

   if self._has_init then
      init = self._init
   end

   if type(action) == "string" then
      action = actions[action]
   end

   return action, init
end

-- Returns placeholder for `narg`-th argument.
function Argument:_get_argname(narg)
   local argname = self._argname or self:_get_default_argname()

   if type(argname) == "table" then
      return argname[narg]
   else
      return argname
   end
end

function Argument:_get_default_argname()
   return "<" .. self._name .. ">"
end

function Option:_get_default_argname()
   return "<" .. self:_get_default_target() .. ">"
end

-- Returns labels to be shown in the help message.
function Argument:_get_label_lines()
   return {self._name}
end

function Option:_get_label_lines()
   local argument_list = self:_get_argument_list()

   if #argument_list == 0 then
      -- Don't put aliases for simple flags like `-h` on different lines.
      return {table.concat(self._aliases, ", ")}
   end

   local longest_alias_length = -1

   for _, alias in ipairs(self._aliases) do
      longest_alias_length = math.max(longest_alias_length, #alias)
   end

   local argument_list_repr = table.concat(argument_list, " ")
   local lines = {}

   for i, alias in ipairs(self._aliases) do
      local line = (" "):rep(longest_alias_length - #alias) .. alias .. " " .. argument_list_repr

      if i ~= #self._aliases then
         line = line .. ","
      end

      table.insert(lines, line)
   end

   return lines
end

function Command:_get_label_lines()
   return {table.concat(self._aliases, ", ")}
end

function Argument:_get_description()
   if self._default and self._show_default then
      if self._description then
         return ("%s (default: %s)"):format(self._description, self._default)
      else
         return ("default: %s"):format(self._default)
      end
   else
      return self._description or ""
   end
end

function Command:_get_description()
   return self._description or ""
end

function Option:_get_usage()
   local usage = self:_get_argument_list()
   table.insert(usage, 1, self._name)
   usage = table.concat(usage, " ")

   if self._mincount == 0 or self._default then
      usage = "[" .. usage .. "]"
   end

   return usage
end

function Argument:_get_default_target()
   return self._name
end

function Option:_get_default_target()
   local res

   for _, alias in ipairs(self._aliases) do
      if alias:sub(1, 1) == alias:sub(2, 2) then
         res = alias:sub(3)
         break
      end
   end

   res = res or self._name:sub(2)
   return (res:gsub("-", "_"))
end

function Option:_is_vararg()
   return self._maxargs ~= self._minargs
end

function Parser:_get_fullname()
   local parent = self._parent
   local buf = {self._name}

   while parent do
      table.insert(buf, 1, parent._name)
      parent = parent._parent
   end

   return table.concat(buf, " ")
end

function Parser:_update_charset(charset)
   charset = charset or {}

   for _, command in ipairs(self._commands) do
      command:_update_charset(charset)
   end

   for _, option in ipairs(self._options) do
      for _, alias in ipairs(option._aliases) do
         charset[alias:sub(1, 1)] = true
      end
   end

   return charset
end

function Parser:argument(...)
   local argument = Argument(...)
   table.insert(self._arguments, argument)
   return argument
end

function Parser:option(...)
   local option = Option(...)

   if self._has_help then
      table.insert(self._options, #self._options, option)
   else
      table.insert(self._options, option)
   end

   return option
end

function Parser:flag(...)
   return self:option():args(0)(...)
end

function Parser:command(...)
   local command = Command():add_help(true)(...)
   command._parent = self
   table.insert(self._commands, command)
   return command
end

function Parser:mutex(...)
   local elements = {...}

   for i, element in ipairs(elements) do
      local mt = getmetatable(element)
      assert(mt == Option or mt == Argument, ("bad argument #%d to 'mutex' (Option or Argument expected)"):format(i))
   end

   table.insert(self._mutexes, elements)
   return self
end

function Parser:group(name, ...)
   assert(type(name) == "string", ("bad argument #1 to 'group' (string expected, got %s)"):format(type(name)))

   local group = {name = name, ...}

   for i, element in ipairs(group) do
      local mt = getmetatable(element)
      assert(mt == Option or mt == Argument or mt == Command,
         ("bad argument #%d to 'group' (Option or Argument or Command expected)"):format(i + 1))
   end

   table.insert(self._groups, group)
   return self
end

local usage_welcome = "Usage: "

function Parser:get_usage()
   if self._usage then
      return self._usage
   end

   local usage_margin = self:_inherit_property("usage_margin", #usage_welcome)
   local max_usage_width = self:_inherit_property("usage_max_width", 70)
   local lines = {usage_welcome .. self:_get_fullname()}

   local function add(s)
      if #lines[#lines]+1+#s <= max_usage_width then
         lines[#lines] = lines[#lines] .. " " .. s
      else
         lines[#lines+1] = (" "):rep(usage_margin) .. s
      end
   end

   -- Normally options are before positional arguments in usage messages.
   -- However, vararg options should be after, because they can't be reliable used
   -- before a positional argument.
   -- Mutexes come into play, too, and are shown as soon as possible.
   -- Overall, output usages in the following order:
   -- 1. Mutexes that don't have positional arguments or vararg options.
   -- 2. Options that are not in any mutexes and are not vararg.
   -- 3. Positional arguments - on their own or as a part of a mutex.
   -- 4. Remaining mutexes.
   -- 5. Remaining options.

   local elements_in_mutexes = {}
   local added_elements = {}
   local added_mutexes = {}
   local argument_to_mutexes = {}

   local function add_mutex(mutex, main_argument)
      if added_mutexes[mutex] then
         return
      end

      added_mutexes[mutex] = true
      local buf = {}

      for _, element in ipairs(mutex) do
         if not element._hidden and not added_elements[element] then
            if getmetatable(element) == Option or element == main_argument then
               table.insert(buf, element:_get_usage())
               added_elements[element] = true
            end
         end
      end

      if #buf == 1 then
         add(buf[1])
      elseif #buf > 1 then
         add("(" .. table.concat(buf, " | ") .. ")")
      end
   end

   local function add_element(element)
      if not element._hidden and not added_elements[element] then
         add(element:_get_usage())
         added_elements[element] = true
      end
   end

   for _, mutex in ipairs(self._mutexes) do
      local is_vararg = false
      local has_argument = false

      for _, element in ipairs(mutex) do
         if getmetatable(element) == Option then
            if element:_is_vararg() then
               is_vararg = true
            end
         else
            has_argument = true
            argument_to_mutexes[element] = argument_to_mutexes[element] or {}
            table.insert(argument_to_mutexes[element], mutex)
         end

         elements_in_mutexes[element] = true
      end

      if not is_vararg and not has_argument then
         add_mutex(mutex)
      end
   end

   for _, option in ipairs(self._options) do
      if not elements_in_mutexes[option] and not option:_is_vararg() then
         add_element(option)
      end
   end

   -- Add usages for positional arguments, together with one mutex containing them, if they are in a mutex.
   for _, argument in ipairs(self._arguments) do
      -- Pick a mutex as a part of which to show this argument, take the first one that's still available.
      local mutex

      if elements_in_mutexes[argument] then
         for _, argument_mutex in ipairs(argument_to_mutexes[argument]) do
            if not added_mutexes[argument_mutex] then
               mutex = argument_mutex
            end
         end
      end

      if mutex then
         add_mutex(mutex, argument)
      else
         add_element(argument)
      end
   end

   for _, mutex in ipairs(self._mutexes) do
      add_mutex(mutex)
   end

   for _, option in ipairs(self._options) do
      add_element(option)
   end

   if #self._commands > 0 then
      if self._require_command then
         add("<command>")
      else
         add("[<command>]")
      end

      add("...")
   end

   return table.concat(lines, "\n")
end

local function split_lines(s)
   if s == "" then
      return {}
   end

   local lines = {}

   if s:sub(-1) ~= "\n" then
      s = s .. "\n"
   end

   for line in s:gmatch("([^\n]*)\n") do
      table.insert(lines, line)
   end

   return lines
end

local function autowrap_line(line, max_length)
   -- Algorithm for splitting lines is simple and greedy.
   local result_lines = {}

   -- Preserve original indentation of the line, put this at the beginning of each result line.
   -- If the first word looks like a list marker ('*', '+', or '-'), add spaces so that starts
   -- of the second and the following lines vertically align with the start of the second word.
   local indentation = line:match("^ *")

   if line:find("^ *[%*%+%-]") then
      indentation = indentation .. " " .. line:match("^ *[%*%+%-]( *)")
   end

   -- Parts of the last line being assembled.
   local line_parts = {}

   -- Length of the current line.
   local line_length = 0

   -- Index of the next character to consider.
   local index = 1

   while true do
      local word_start, word_finish, word = line:find("([^ ]+)", index)

      if not word_start then
         -- Ignore trailing spaces, if any.
         break
      end

      local preceding_spaces = line:sub(index, word_start - 1)
      index = word_finish + 1

      if (#line_parts == 0) or (line_length + #preceding_spaces + #word <= max_length) then
         -- Either this is the very first word or it fits as an addition to the current line, add it.
         table.insert(line_parts, preceding_spaces) -- For the very first word this adds the indentation.
         table.insert(line_parts, word)
         line_length = line_length + #preceding_spaces + #word
      else
         -- Does not fit, finish current line and put the word into a new one.
         table.insert(result_lines, table.concat(line_parts))
         line_parts = {indentation, word}
         line_length = #indentation + #word
      end
   end

   if #line_parts > 0 then
      table.insert(result_lines, table.concat(line_parts))
   end

   if #result_lines == 0 then
      -- Preserve empty lines.
      result_lines[1] = ""
   end

   return result_lines
end

-- Automatically wraps lines within given array,
-- attempting to limit line length to `max_length`.
-- Existing line splits are preserved.
local function autowrap(lines, max_length)
   local result_lines = {}

   for _, line in ipairs(lines) do
      local autowrapped_lines = autowrap_line(line, max_length)

      for _, autowrapped_line in ipairs(autowrapped_lines) do
         table.insert(result_lines, autowrapped_line)
      end
   end

   return result_lines
end

function Parser:_get_element_help(element)
   local label_lines = element:_get_label_lines()
   local description_lines = split_lines(element:_get_description())

   local result_lines = {}

   -- All label lines should have the same length (except the last one, it has no comma).
   -- If too long, start description after all the label lines.
   -- Otherwise, combine label and description lines.

   local usage_margin_len = self:_inherit_property("help_usage_margin", 3)
   local usage_margin = (" "):rep(usage_margin_len)
   local description_margin_len = self:_inherit_property("help_description_margin", 25)
   local description_margin = (" "):rep(description_margin_len)

   local help_max_width = self:_inherit_property("help_max_width")

   if help_max_width then
      local description_max_width = math.max(help_max_width - description_margin_len, 10)
      description_lines = autowrap(description_lines, description_max_width)
   end

   if #label_lines[1] >= (description_margin_len - usage_margin_len) then
      for _, label_line in ipairs(label_lines) do
         table.insert(result_lines, usage_margin .. label_line)
      end

      for _, description_line in ipairs(description_lines) do
         table.insert(result_lines, description_margin .. description_line)
      end
   else
      for i = 1, math.max(#label_lines, #description_lines) do
         local label_line = label_lines[i]
         local description_line = description_lines[i]

         local line = ""

         if label_line then
            line = usage_margin .. label_line
         end

         if description_line and description_line ~= "" then
            line = line .. (" "):rep(description_margin_len - #line) .. description_line
         end

         table.insert(result_lines, line)
      end
   end

   return table.concat(result_lines, "\n")
end

local function get_group_types(group)
   local types = {}

   for _, element in ipairs(group) do
      types[getmetatable(element)] = true
   end

   return types
end

function Parser:_add_group_help(blocks, added_elements, label, elements)
   local buf = {label}

   for _, element in ipairs(elements) do
      if not element._hidden and not added_elements[element] then
         added_elements[element] = true
         table.insert(buf, self:_get_element_help(element))
      end
   end

   if #buf > 1 then
      table.insert(blocks, table.concat(buf, ("\n"):rep(self:_inherit_property("help_vertical_space", 0) + 1)))
   end
end

function Parser:get_help()
   if self._help then
      return self._help
   end

   local blocks = {self:get_usage()}

   local help_max_width = self:_inherit_property("help_max_width")

   if self._description then
      local description = self._description

      if help_max_width then
         description = table.concat(autowrap(split_lines(description), help_max_width), "\n")
      end

      table.insert(blocks, description)
   end

   -- 1. Put groups containing arguments first, then other arguments.
   -- 2. Put remaining groups containing options, then other options.
   -- 3. Put remaining groups containing commands, then other commands.
   -- Assume that an element can't be in several groups.
   local groups_by_type = {
      [Argument] = {},
      [Option] = {},
      [Command] = {}
   }

   for _, group in ipairs(self._groups) do
      local group_types = get_group_types(group)

      for _, mt in ipairs({Argument, Option, Command}) do
         if group_types[mt] then
            table.insert(groups_by_type[mt], group)
            break
         end
      end
   end

   local default_groups = {
      {name = "Arguments", type = Argument, elements = self._arguments},
      {name = "Options", type = Option, elements = self._options},
      {name = "Commands", type = Command, elements = self._commands}
   }

   local added_elements = {}

   for _, default_group in ipairs(default_groups) do
      local type_groups = groups_by_type[default_group.type]

      for _, group in ipairs(type_groups) do
         self:_add_group_help(blocks, added_elements, group.name .. ":", group)
      end

      local default_label = default_group.name .. ":"

      if #type_groups > 0 then
         default_label = "Other " .. default_label:gsub("^.", string.lower)
      end

      self:_add_group_help(blocks, added_elements, default_label, default_group.elements)
   end

   if self._epilog then
      local epilog = self._epilog

      if help_max_width then
         epilog = table.concat(autowrap(split_lines(epilog), help_max_width), "\n")
      end

      table.insert(blocks, epilog)
   end

   return table.concat(blocks, "\n\n")
end

local function get_tip(context, wrong_name)
   local context_pool = {}
   local possible_name
   local possible_names = {}

   for name in pairs(context) do
      if type(name) == "string" then
         for i = 1, #name do
            possible_name = name:sub(1, i - 1) .. name:sub(i + 1)

            if not context_pool[possible_name] then
               context_pool[possible_name] = {}
            end

            table.insert(context_pool[possible_name], name)
         end
      end
   end

   for i = 1, #wrong_name + 1 do
      possible_name = wrong_name:sub(1, i - 1) .. wrong_name:sub(i + 1)

      if context[possible_name] then
         possible_names[possible_name] = true
      elseif context_pool[possible_name] then
         for _, name in ipairs(context_pool[possible_name]) do
            possible_names[name] = true
         end
      end
   end

   local first = next(possible_names)

   if first then
      if next(possible_names, first) then
         local possible_names_arr = {}

         for name in pairs(possible_names) do
            table.insert(possible_names_arr, "'" .. name .. "'")
         end

         table.sort(possible_names_arr)
         return "\nDid you mean one of these: " .. table.concat(possible_names_arr, " ") .. "?"
      else
         return "\nDid you mean '" .. first .. "'?"
      end
   else
      return ""
   end
end

local ElementState = class({
   invocations = 0
})

function ElementState:__call(state, element)
   self.state = state
   self.result = state.result
   self.element = element
   self.target = element._target or element:_get_default_target()
   self.action, self.result[self.target] = element:_get_action()
   return self
end

function ElementState:error(fmt, ...)
   self.state:error(fmt, ...)
end

function ElementState:convert(argument, index)
   local converter = self.element._convert

   if converter then
      local ok, err

      if type(converter) == "function" then
         ok, err = converter(argument)
      elseif type(converter[index]) == "function" then
         ok, err = converter[index](argument)
      else
         ok = converter[argument]
      end

      if ok == nil then
         self:error(err and "%s" or "malformed argument '%s'", err or argument)
      end

      argument = ok
   end

   return argument
end

function ElementState:default(mode)
   return self.element._defmode:find(mode) and self.element._default
end

local function bound(noun, min, max, is_max)
   local res = ""

   if min ~= max then
      res = "at " .. (is_max and "most" or "least") .. " "
   end

   local number = is_max and max or min
   return res .. tostring(number) .. " " .. noun ..  (number == 1 and "" or "s")
end

function ElementState:set_name(alias)
   self.name = ("%s '%s'"):format(alias and "option" or "argument", alias or self.element._name)
end

function ElementState:invoke()
   self.open = true
   self.overwrite = false

   if self.invocations >= self.element._maxcount then
      if self.element._overwrite then
         self.overwrite = true
      else
         local num_times_repr = bound("time", self.element._mincount, self.element._maxcount, true)
         self:error("%s must be used %s", self.name, num_times_repr)
      end
   else
      self.invocations = self.invocations + 1
   end

   self.args = {}

   if self.element._maxargs <= 0 then
      self:close()
   end

   return self.open
end

function ElementState:pass(argument)
   argument = self:convert(argument, #self.args + 1)
   table.insert(self.args, argument)

   if #self.args >= self.element._maxargs then
      self:close()
   end

   return self.open
end

function ElementState:complete_invocation()
   while #self.args < self.element._minargs do
      self:pass(self.element._default)
   end
end

function ElementState:close()
   if self.open then
      self.open = false

      if #self.args < self.element._minargs then
         if self:default("a") then
            self:complete_invocation()
         else
            if #self.args == 0 then
               if getmetatable(self.element) == Argument then
                  self:error("missing %s", self.name)
               elseif self.element._maxargs == 1 then
                  self:error("%s requires an argument", self.name)
               end
            end

            self:error("%s requires %s", self.name, bound("argument", self.element._minargs, self.element._maxargs))
         end
      end

      local args

      if self.element._maxargs == 0 then
         args = self.args[1]
      elseif self.element._maxargs == 1 then
         if self.element._minargs == 0 and self.element._mincount ~= self.element._maxcount then
            args = self.args
         else
            args = self.args[1]
         end
      else
         args = self.args
      end

      self.action(self.result, self.target, args, self.overwrite)
   end
end

local ParseState = class({
   result = {},
   options = {},
   arguments = {},
   argument_i = 1,
   element_to_mutexes = {},
   mutex_to_element_state = {},
   command_actions = {}
})

function ParseState:__call(parser, error_handler)
   self.parser = parser
   self.error_handler = error_handler
   self.charset = parser:_update_charset()
   self:switch(parser)
   return self
end

function ParseState:error(fmt, ...)
   self.error_handler(self.parser, fmt:format(...))
end

function ParseState:switch(parser)
   self.parser = parser

   if parser._action then
      table.insert(self.command_actions, {action = parser._action, name = parser._name})
   end

   for _, option in ipairs(parser._options) do
      option = ElementState(self, option)
      table.insert(self.options, option)

      for _, alias in ipairs(option.element._aliases) do
         self.options[alias] = option
      end
   end

   for _, mutex in ipairs(parser._mutexes) do
      for _, element in ipairs(mutex) do
         if not self.element_to_mutexes[element] then
            self.element_to_mutexes[element] = {}
         end

         table.insert(self.element_to_mutexes[element], mutex)
      end
   end

   for _, argument in ipairs(parser._arguments) do
      argument = ElementState(self, argument)
      table.insert(self.arguments, argument)
      argument:set_name()
      argument:invoke()
   end

   self.handle_options = parser._handle_options
   self.argument = self.arguments[self.argument_i]
   self.commands = parser._commands

   for _, command in ipairs(self.commands) do
      for _, alias in ipairs(command._aliases) do
         self.commands[alias] = command
      end
   end
end

function ParseState:get_option(name)
   local option = self.options[name]

   if not option then
      self:error("unknown option '%s'%s", name, get_tip(self.options, name))
   else
      return option
   end
end

function ParseState:get_command(name)
   local command = self.commands[name]

   if not command then
      if #self.commands > 0 then
         self:error("unknown command '%s'%s", name, get_tip(self.commands, name))
      else
         self:error("too many arguments")
      end
   else
      return command
   end
end

function ParseState:check_mutexes(element_state)
   if self.element_to_mutexes[element_state.element] then
      for _, mutex in ipairs(self.element_to_mutexes[element_state.element]) do
         local used_element_state = self.mutex_to_element_state[mutex]

         if used_element_state and used_element_state ~= element_state then
            self:error("%s can not be used together with %s", element_state.name, used_element_state.name)
         else
            self.mutex_to_element_state[mutex] = element_state
         end
      end
   end
end

function ParseState:invoke(option, name)
   self:close()
   option:set_name(name)
   self:check_mutexes(option, name)

   if option:invoke() then
      self.option = option
   end
end

function ParseState:pass(arg)
   if self.option then
      if not self.option:pass(arg) then
         self.option = nil
      end
   elseif self.argument then
      self:check_mutexes(self.argument)

      if not self.argument:pass(arg) then
         self.argument_i = self.argument_i + 1
         self.argument = self.arguments[self.argument_i]
      end
   else
      local command = self:get_command(arg)
      self.result[command._target or command._name] = true

      if self.parser._command_target then
         self.result[self.parser._command_target] = command._name
      end

      self:switch(command)
   end
end

function ParseState:close()
   if self.option then
      self.option:close()
      self.option = nil
   end
end

function ParseState:finalize()
   self:close()

   for i = self.argument_i, #self.arguments do
      local argument = self.arguments[i]
      if #argument.args == 0 and argument:default("u") then
         argument:complete_invocation()
      else
         argument:close()
      end
   end

   if self.parser._require_command and #self.commands > 0 then
      self:error("a command is required")
   end

   for _, option in ipairs(self.options) do
      option.name = option.name or ("option '%s'"):format(option.element._name)

      if option.invocations == 0 then
         if option:default("u") then
            option:invoke()
            option:complete_invocation()
            option:close()
         end
      end

      local mincount = option.element._mincount

      if option.invocations < mincount then
         if option:default("a") then
            while option.invocations < mincount do
               option:invoke()
               option:close()
            end
         elseif option.invocations == 0 then
            self:error("missing %s", option.name)
         else
            self:error("%s must be used %s", option.name, bound("time", mincount, option.element._maxcount))
         end
      end
   end

   for i = #self.command_actions, 1, -1 do
      self.command_actions[i].action(self.result, self.command_actions[i].name)
   end
end

function ParseState:parse(args)
   for _, arg in ipairs(args) do
      local plain = true

      if self.handle_options then
         local first = arg:sub(1, 1)

         if self.charset[first] then
            if #arg > 1 then
               plain = false

               if arg:sub(2, 2) == first then
                  if #arg == 2 then
                     if self.options[arg] then
                        local option = self:get_option(arg)
                        self:invoke(option, arg)
                     else
                        self:close()
                     end

                     self.handle_options = false
                  else
                     local equals = arg:find "="
                     if equals then
                        local name = arg:sub(1, equals - 1)
                        local option = self:get_option(name)

                        if option.element._maxargs <= 0 then
                           self:error("option '%s' does not take arguments", name)
                        end

                        self:invoke(option, name)
                        self:pass(arg:sub(equals + 1))
                     else
                        local option = self:get_option(arg)
                        self:invoke(option, arg)
                     end
                  end
               else
                  for i = 2, #arg do
                     local name = first .. arg:sub(i, i)
                     local option = self:get_option(name)
                     self:invoke(option, name)

                     if i ~= #arg and option.element._maxargs > 0 then
                        self:pass(arg:sub(i + 1))
                        break
                     end
                  end
               end
            end
         end
      end

      if plain then
         self:pass(arg)
      end
   end

   self:finalize()
   return self.result
end

function Parser:error(msg)
   io.stderr:write(("%s\n\nError: %s\n"):format(self:get_usage(), msg))
   os.exit(1)
end

-- Compatibility with strict.lua and other checkers:
local default_cmdline = rawget(_G, "arg") or {}

function Parser:_parse(args, error_handler)
   return ParseState(self, error_handler):parse(args or default_cmdline)
end

function Parser:parse(args)
   return self:_parse(args, self.error)
end

local function xpcall_error_handler(err)
   return tostring(err) .. "\noriginal " .. debug.traceback("", 2):sub(2)
end

function Parser:pparse(args)
   local parse_error

   local ok, result = xpcall(function()
      return self:_parse(args, function(_, err)
         parse_error = err
         error(err, 0)
      end)
   end, xpcall_error_handler)

   if ok then
      return true, result
   elseif not parse_error then
      error(result, 0)
   else
      return false, parse_error
   end
end

local argparse = {}

argparse.version = "0.6.0"

setmetatable(argparse, {__call = function(_, ...)
   return Parser(default_cmdline[0]):add_help(true)(...)
end})

return argparse

end,

["scholarlyMetadata"] = function()
--------------------
-- Module: 'scholarlyMetadata'
--------------------
--[[
ScholarlyMeta – normalize author/affiliation meta variables

Copyright (c) 2017-2021 Albert Krewinkel, Robert Winkler
Modified by Julien Dutant 2024

Permission to use, copy, modify, and/or distribute this software for any purpose
with or without fee is hereby granted, provided that the above copyright notice
and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
THIS SOFTWARE.
]]
local List = pandoc.List
local stringify = pandoc.utils.stringify
local type = pandoc.utils.type

-- Split a string at commas.
local function comma_separated_values(str)
  local acc = List:new{}
  for substr in str:gmatch('([^,]*)') do
    acc[#acc + 1] = substr:gsub('^%s*', ''):gsub('%s*$', '') -- trim
  end
  return acc
end

--- Ensure the return value is a list.
local function ensure_list (val)
  if type(val) == 'List' then
    return val
  elseif type(val) == 'Inlines' then
    -- check if this is really a comma-separated list
    local csv = comma_separated_values(stringify(val))
    if #csv >= 2 then
      return csv
    end
    return List:new{val}
  elseif type(val) == 'table' and #val > 0 then
    return List:new(val)
  else
    -- Anything else, use as a singleton (or empty list if val == nil).
    return List:new{val}
  end
end

--- Returns a function which checks whether an object has the given ID.
local function has_id (id)
  return function(x) return x.id == id end
end

--- Copy all key-value pairs of the first table into the second iff there is no
-- such key yet in the second table.
-- @returns the second argument
function add_missing_entries(a, b)
  for k, v in pairs(a) do
    b[k] = b[k] or v
  end
  return b
end

--- Create an object with a name. The name is either taken directly from the
-- `name` field, or from the *only* field name (i.e., key) if the object is a
-- dictionary with just one entry. If neither exists, the name is left unset
-- (`nil`).
function to_named_object (obj)
  local named = {}
  if type(obj) == 'Inlines' then
    -- Treat inlines as the name
    named.name = obj
    named.id = stringify(obj)
  elseif type(obj) ~= 'table' then
    -- if the object isn't a table, just use its value as a name.
    named.name = pandoc.MetaInlines{pandoc.Str(tostring(obj))}
    named.id = tostring(obj)
  elseif obj.name ~= nil then
    -- object has name attribute → just create a copy of the object
    add_missing_entries(obj, named)
    named.id = stringify(named.id or named.name)
  elseif next(obj) and next(obj, next(obj)) == nil then
    -- Single-entry table. The entry's key is taken as the name, the value
    -- contains the attributes.
    key, attribs = next(obj)
    if type(attribs) == 'string' or type(attribs) == 'Inlines' then
      named.name = attribs
    else
      add_missing_entries(attribs, named)
      named.name = named.name or pandoc.MetaInlines{pandoc.Str(tostring(key))}
    end
    named.id = named.id and stringify(named.id) or key
  else
    -- this is not a named object adhering to the usual conventions.
    error('not a named object: ' .. tostring(obj))
  end
  return named
end

--- Resolve institute placeholders to full named objects
local function resolve_institutes (institute, known_institutes)
  local unresolved_institutes
  if institute == nil then
    unresolved_institutes = {}
  elseif type(institute) == "string" or type(institute) == "number" then
    unresolved_institutes = {institute}
  else
    unresolved_institutes = institute
  end

  local result = List:new{}
  for i, inst in ipairs(unresolved_institutes) do
    result[i] =
      known_institutes[tonumber(inst)] or
      known_institutes:find_if(has_id(stringify(inst))) or
      to_named_object(inst)
  end
  return result
end

--- Insert a named object into a list; if an object of the same name exists
-- already, add all properties only present in the new object to the existing
-- item.
function merge_on_id (list, namedObj)
  local elem, idx = list:find_if(has_id(namedObj.id))
  local res = elem and add_missing_entries(namedObj, elem) or namedObj
  local obj_idx = idx or (#list + 1)
  -- return res, obj_idx
  list[obj_idx] = res
  return res, #list
end

--- Flatten a list of lists.
local function flatten (lists)
  local result = List:new{}
  for _, lst in ipairs(lists) do
    result:extend(lst)
  end
  return result
end

--- Canonicalize authors and institutes
local function canonicalize(raw_author, raw_institute)
  local institutes = ensure_list(raw_institute):map(to_named_object)
  local authors = ensure_list(raw_author):map(to_named_object)

  for _, author in ipairs(authors) do
    author.institute = resolve_institutes(
      ensure_list(author.institute),
      institutes
    )
  end

  -- Merge institutes defined in author objects with those defined in the
  -- top-level list.
  local author_insts = flatten(authors:map(function(x) return x.institute end))
  for _, inst in ipairs(author_insts) do
    merge_on_id(institutes, inst)
  end

  -- Add list indices to institutes for numbering and reference purposes
  for idx, inst in ipairs(institutes) do
    inst.index = pandoc.MetaInlines{pandoc.Str(tostring(idx))}
  end

  -- replace institutes with their indices
  local to_index = function (inst)
    return tostring(select(2, institutes:find_if(has_id(inst.id))))
  end
  for _, author in ipairs(authors) do
    author.institute = pandoc.MetaList(author.institute:map(to_index))
  end

  return authors, institutes
end

local function scholarlyMetadata(meta)
  meta.author, meta.institute = canonicalize(meta.author, meta.institute)
  return meta
end

return scholarlyMetadata
end,

["log"] = function()
--------------------
-- Module: 'log'
--------------------
---Logs a message on standard error.
---@param type 'INFO'|'WARNING'|'ERROR'
---@param text string
local function log(type, text)
    local level = {INFO = 0, WARNING = 1, ERROR = 2}
    local verb = VERBOSITY or 'WARNING'
    if level[type] == nil then type = 'ERROR' end
    if level[verb] <= level[type] then
        local message = '[' .. type .. '] '..text..'\n'
        io.stderr:write(message)
    end
end

return log
end,

["Collection"] = function()
--------------------
-- Module: 'Collection'
--------------------
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

end,

["pathx"] = function()
--------------------
-- Module: 'pathx'
--------------------
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
end,

["Job"] = function()
--------------------
-- Module: 'Job'
--------------------
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



end,

----------------------
-- Modules part end --
----------------------
        }
        if files[path] then
            return files[path]
        else
            return origin_seacher(path)
        end
    end
end
---------------------------------------------------------
----------------Auto generated code block----------------
---------------------------------------------------------
--[[ dialoa2json.lua: Exports Dialoa journal metadata as JSON

@author Julien Dutant <https://github.com/jdutant>
@copyright 2024 Philosophie.ch
@license MIT - see LICENSE file for details.

]]

local argparse = require('argparse')
local log = require('log')
local Job = require('Job')
local Collection = require('Collection')
local Issue = require('Issue')

-- # General settings
VERBOSITY = 'WARNING'

---Create and parse command line arguments
---@return Job job
local function CLIargs()
    local parser = argparse("Pandoc Lua Importer",
        "Export issue or article metadata in JSON format.")
    parser:argument("source", "Issue master file.")
    parser:flag("-i --issue", "Export the issue.")
    parser:option("-a --article", 
        "Number of an article to export (repeatable)."):count('*')
    parser:option("--metadata-file", "Metadata file to add to the master (yaml)."):count('*')
    parser:mutex(
        parser:flag("-q --quiet", "Quiet output (errors only)."),
        parser:flag("-v --verbose", "Verbose output.")
    )

    local args = parser:parse()

    if args.quiet then
        VERBOSITY = 'ERROR'
    elseif args.verbose then
        VERBOSITY = 'INFO'
    end

    local source = args.source
    local issue = args.issue or false
    local items = args.article
    local job = Job:new(source, issue, items)

    if not job then
        log('ERROR', 'Could not start job. Aborting.')
        os.exit(1)
    end

    if args.metadata_file then
        job:addMetadataFiles(args.metadata_file)
    end

    return job
end

-- # Main script

local job = CLIargs()
local col = Collection:new(job.source, job.metadataFiles)
local issue = Issue:new(col, job)

-- print(pandoc.write(
--     pandoc.Pandoc({}, col.masterMeta), 'markdown',
--     {template = pandoc.template.default('markdown')}))

local tbl = Issue:getIssue()
local function unpack(t, prefix)
    local result = ''
    local prefix = prefix or ''
    for k,v in pairs(t) do
        if type(v) == 'string' or type(v) == 'number' or type(v) == 'boolean' then
            result = result..prefix..k..'    '..tostring(v)..'\n'
        elseif type(v) == 'table' then
            result = result..prefix..k..' {\n'
                ..unpack(v, '    ')
                ..prefix..'}\n'
        end
    end
    return result
end

print(unpack(tbl))
