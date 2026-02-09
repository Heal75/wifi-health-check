#!/usr/bin/lua

local duration = tonumber(arg[1]) or 60

function read_stats()
    local stats = {}
    local f = io.open("/proc/net/dev", "r")
    if not f then return nil end
    
    for line in f:lines() do
        -- Match interface name and capture the first block of numbers (RX stats)
        local iface, rx_bytes, rx_pkts, rx_errs, rx_drop, rx_fifo, rx_frame = 
            string.match(line, "^%s*([%w%.%-_]+):%s*(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")
            
        if iface and (string.match(iface, "wl") or string.match(iface, "wlan") or string.match(iface, "ath") or string.match(iface, "ra")) then
            stats[iface] = {
                rx = tonumber(rx_pkts),
                frame = tonumber(rx_frame), -- Interference
                fifo = tonumber(rx_fifo)    -- RAM/CPU
            }
        end
    end
    f:close()
    return stats
end

print(string.format("Monitoring WiFi for %d seconds...", duration))
local start_data = read_stats()
os.execute("sleep " .. duration)
local end_data = read_stats()

print(string.format("%-12s | %-10s | %-10s | %-10s | %s", "Interface", "RX Pkts", "RF Noise", "CPU/RAM", "Status"))
print(string.rep("-", 65))

for iface, s_stat in pairs(start_data) do
    local e_stat = end_data[iface]
    if e_stat then
        local d_rx = e_stat.rx - s_stat.rx
        local d_frame = e_stat.frame - s_stat.frame
        local d_fifo = e_stat.fifo - s_stat.fifo
        
        local diag = "🟢 OK"
        if d_fifo > 0 then diag = "🔴 RAM/CPU CHOKE"
        elseif d_frame > 1000 then diag = "🔴 HIGH NOISE"
        elseif d_frame > 50 then diag = "⚠️ INTERFERENCE"
        end

        print(string.format("%-12s | %-10d | %-10d | %-10d | %s", iface, d_rx, d_frame, d_fifo, diag))
    end
end