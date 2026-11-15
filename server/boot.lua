CreateThread(function()
    if not Kora.sql.ready(60000) then Kora.logging.error('schema.sql_unavailable', 'kora_sql unavailable; records terminal will not start'); return end

    -- kora_core creates the players table in its own schema setup; reports that include a citizen ID query
    -- players.deleted_at, so wait for it before starting.
    if not Kora.sql.awaitTables({ 'players' }, 60000) then
        Kora.logging.error('schema.player_table_unavailable', 'kora_core player schema unavailable; report creation will remain disabled')
        return
    end

    local reports, err = Kora.sql.ensureTables(KoraMdtSchema)
    if err or not reports then Kora.logging.error('schema.setup_failed', 'Schema setup failed', { error = tostring(err) }); return end
    for _, report in ipairs(reports) do
        for _, warning in ipairs(report.warnings or {}) do
            Kora.logging.warn('schema.warning', 'Schema reported a warning', { table = tostring(report.table), warning = tostring(warning) })
        end
    end
    TriggerEvent('kora_mdt:server:databaseReady')
end)
