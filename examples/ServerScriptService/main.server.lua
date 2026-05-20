-- ServerScript: spins "Cube 1" on the server.
--
-- This engine's scripting API is deliberately flat and handle-based — no
-- game:GetService(...):FindFirstChild(...) object-graph traversal. You ask
-- the scene for an entity by name once, get a stable integer handle, and
-- cache it. The server replicates every entity transform each tick, so just
-- mutating the entity here makes it move on every connected client.

local cube = nil          -- cached entity handle (nil until found)

function on_tick(dt)
  -- Resolve the handle lazily and re-resolve if it ever goes stale.
  if cube == nil or engine.exists(cube) == false then
    cube = engine.find("Cube 1")
  end
  if cube == nil then
    return
  end
  -- Rotate about the Y axis (axis 2) at 1.5 rad/s, world-space.
  engine.rotate_world(cube, 2, dt * 1.5)
end
