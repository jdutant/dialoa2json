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