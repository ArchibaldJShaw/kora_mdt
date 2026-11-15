-- Behavioural check: failed boot paths emit Kora.logging calls (not print) with the error in fields.
local h = dofile('test/harness.lua')

local function run(sqlOverrides)
    local calls = {}
    local spy = function(level)
        return function(event, message, fields) calls[#calls + 1] = { level = level, event = event, message = message, fields = fields } return true end
    end
    local sql = { ready = function() return true end, awaitTables = function() return true end,
        ensureTables = function() return {} end }
    for k, v in pairs(sqlOverrides) do sql[k] = v end
    _G.Kora = { sql = sql, logging = { error = spy('error'), warn = spy('warn'), info = spy('info'), debug = spy('debug'),
        isEnabled = function() return true end } }
    _G.KoraMdtSchema = {}
    _G.CreateThread = function(fn) fn() end
    _G.TriggerEvent = function() end
    local printed = false
    local realPrint = print
    _G.print = function() printed = true end
    dofile('server/boot.lua')
    _G.print = realPrint
    return calls, printed
end

h.test('schema setup failure logs schema.setup_failed with the error in fields', function()
    local calls, printed = run({ ensureTables = function() return nil, 'boom' end })
    h.assertEqual(#calls, 1, 'one logger call')
    h.assertEqual(calls[1].level, 'error', 'level')
    h.assertEqual(calls[1].event, 'schema.setup_failed', 'event')
    h.assertEqual(calls[1].fields.error, 'boom', 'error field')
    h.assertEqual(printed, false, 'no raw print')
end)

h.test('missing kora_sql logs schema.sql_unavailable', function()
    local calls = run({ ready = function() return false end })
    h.assertEqual(calls[1].event, 'schema.sql_unavailable', 'event')
    h.assertEqual(calls[1].level, 'error', 'level')
end)

h.test('schema warnings log at warn level', function()
    local calls = run({ ensureTables = function() return { { table = 't', warnings = { 'w' } } } end })
    h.assertEqual(calls[1].level, 'warn', 'level')
    h.assertEqual(calls[1].fields.warning, 'w', 'warning field')
end)

h.report('kora_mdt logging')
