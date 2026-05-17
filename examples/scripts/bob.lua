-- Bob: vertical oscillation around the entity's spawn Y.
-- Lua keeps state across ticks via the chunk's upvalues, so we capture the
-- starting Y the first time on_tick runs.
local origin_y = nil
local elapsed = 0

function on_tick(dt)
  if origin_y == nil then
    local _, y, _ = engine.get_pos()
    origin_y = y
  end
  elapsed = elapsed + dt
  local x, _, z = engine.get_pos()
  engine.set_pos(x, origin_y + math.sin(elapsed * 2.0) * 0.5, z)
end
