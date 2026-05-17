-- Simple player mover: WASD on the XZ plane, Space/Ctrl on Y. Speed is in
-- world units per second. Reads the engine's input map rather than raw Win32
-- key codes, so rebinding actions Just Works.
local SPEED = 3.0

function on_tick(dt)
  local dx, dz, dy = 0, 0, 0
  if engine.input_held(engine.IA.FORWARD) ~= 0 then dz = dz - 1 end
  if engine.input_held(engine.IA.BACK)    ~= 0 then dz = dz + 1 end
  if engine.input_held(engine.IA.LEFT)    ~= 0 then dx = dx - 1 end
  if engine.input_held(engine.IA.RIGHT)   ~= 0 then dx = dx + 1 end
  if engine.input_held(engine.IA.UP)      ~= 0 then dy = dy + 1 end
  if engine.input_held(engine.IA.DOWN)    ~= 0 then dy = dy - 1 end

  if dx ~= 0 or dz ~= 0 or dy ~= 0 then
    engine.translate(dx * SPEED * dt, dy * SPEED * dt, dz * SPEED * dt)
  end
end
