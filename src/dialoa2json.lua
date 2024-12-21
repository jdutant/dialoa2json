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

