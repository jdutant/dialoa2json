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