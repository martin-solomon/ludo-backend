local nk = require("nakama")

-- RPC: guest_cleanup
-- Accepts: empty payload
-- Behavior: scans storage collection user_profiles for entries with guest=true and last_active/created_at older than threshold_days
local function guest_cleanup(context, payload)
  -- Only allow server key or admin session: require context.user_id nil + server key check?
  -- Simpler: require the call to use server Basic auth (context.user_id will be nil), but check runtime HTTP key is set for your env.
  -- We'll allow any call but log — in production, restrict this using runtime.http_key + server key
  local threshold_days = 60
  local threshold_ms = os.time() * 1000 - (threshold_days * 24 * 60 * 60 * 1000)

  local read_count = 0
  local delete_count = 0

  local cursor = nil
  repeat
    local ok, res = pcall(nk.storage_list, "user_profiles", 1000, cursor)
    if not ok or not res then
      nk.logger_error("guest_cleanup: storage_list failed: " .. tostring(res))
      break
    end
    cursor = res.cursor

    for _, obj in ipairs(res.objects or {}) do
      read_count = read_count + 1
      local value = obj.value or {}
      local is_guest = value.guest
      local last = value.last_active or value.created_at
      if is_guest and last and tonumber(last) and tonumber(last) < threshold_ms then
        -- delete storage object
        local del = {
          { collection = "user_profiles", key = obj.key, user_id = obj.user_id }
        }
        local okd, errd = pcall(nk.storage_delete, del)
        if okd then
          delete_count = delete_count + 1
          nk.logger_info("guest_cleanup: deleted guest user " .. tostring(obj.user_id))
        else
          nk.logger_error("guest_cleanup: failed delete for " .. tostring(obj.user_id) .. " : " .. tostring(errd))
        end
      end
    end
  until not cursor

  return nk.json_encode({ success = true, scanned = read_count, deleted = delete_count })
end

nk.register_rpc(guest_cleanup, "guest_cleanup")
