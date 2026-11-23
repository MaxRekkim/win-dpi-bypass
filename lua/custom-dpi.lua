-- Custom Lua helpers for win-dpi-bypass (zapret2 / winws2)
-- Loaded after zapret-lib.lua, zapret-antidpi.lua, zapret-auto.lua

-- Logs which circular strategy is selected when a host rotates
function custom_log_strategy(ctx, desync)
	if not desync.track then return end
	local hrec = automate_host_record(desync)
	if hrec and hrec.nstrategy and hrec.nstrategy ~= hrec._last_logged_strategy then
		hrec._last_logged_strategy = hrec.nstrategy
		local host = desync.track.hostname or desync.dis.ip_dst or "unknown"
		DLOG("custom_log_strategy: host=" .. tostring(host) .. " active_strategy=" .. tostring(hrec.nstrategy))
	end
end
