-- Custom Lua helpers for win-dpi-bypass (zapret2 / winws2)
-- Loaded after zapret-lib.lua, zapret-antidpi.lua, zapret-auto.lua

-- Dynamic random sequence offset fooling (avoids static -10000 fingerprint)
function custom_fool_randseq(desync, dis, fooling_options)
	if dis and dis.tcp then
		local delta = -math.random(10000, 60000)
		dis.tcp.th_seq = u32add(dis.tcp.th_seq, delta)
	end
end

-- IPv4 / IPv6 condition helpers for `condition` / `stopif`
function cond_is_ipv4(desync)
	return desync.dis and desync.dis.ip ~= nil
end

function cond_is_ipv6(desync)
	return desync.dis and desync.dis.ip6 ~= nil
end

-- Safe per-host strategy logger
function custom_log_strategy(ctx, desync)
	if not desync.track then return end
	local hrec = automate_host_record(desync)
	if hrec and hrec.nstrategy and hrec.nstrategy ~= hrec._last_logged_strategy then
		hrec._last_logged_strategy = hrec.nstrategy
		local host = desync.track.hostname or (desync.dis and ntop(dis_ipdst(desync.dis))) or "unknown"
		DLOG("custom_log_strategy: host=" .. tostring(host) .. " active_strategy=" .. tostring(hrec.nstrategy))
	end
end
