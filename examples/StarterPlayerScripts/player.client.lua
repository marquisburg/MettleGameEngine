-- LocalScript: free mouse-look fly camera.
--
-- This is the practical client-side implementation for gap 1.1: the playtest
-- client no longer runs the editor's fly-cam. The camera is fully script-
-- driven through the engine.camera_* API. This script gives a familiar
-- WASD + mouse-look free camera owned entirely by the client.
--
--   Mouse           -> look (yaw/pitch)
--   W / S           -> forward / back  (along view direction)
--   A / D           -> strafe left / right
--   Space / Ctrl    -> up / down (world)
--   Shift           -> move faster
--
-- engine.camera_forward()/right() return unit basis vectors for the current
-- look so we don't reimplement the trig. Position is in metres.

local LOOK_SENS   = 0.0035   -- radians per mouse pixel
local MOVE_SPEED  = 8.0      -- metres / second
local BOOST_MULT  = 3.0

local yaw, pitch = engine.camera_get_look()

function on_tick(dt)
  -- Mouse-look. dy is inverted so pushing the mouse up looks up.
  local dx, dy = engine.mouse_delta()
  if dx ~= 0 or dy ~= 0 then
    yaw   = yaw   + dx * LOOK_SENS
    pitch = pitch - dy * LOOK_SENS
    engine.camera_set_look(yaw, pitch)
  end

  -- Movement, relative to where the camera is looking.
  local fx, fy, fz = engine.camera_forward()
  local rx, ry, rz = engine.camera_right()
  local mvx, mvy, mvz = 0.0, 0.0, 0.0

  if engine.input_held(engine.IA.FORWARD) ~= 0 then
    mvx = mvx + fx; mvy = mvy + fy; mvz = mvz + fz
  end
  if engine.input_held(engine.IA.BACK) ~= 0 then
    mvx = mvx - fx; mvy = mvy - fy; mvz = mvz - fz
  end
  if engine.input_held(engine.IA.RIGHT) ~= 0 then
    mvx = mvx + rx; mvy = mvy + ry; mvz = mvz + rz
  end
  if engine.input_held(engine.IA.LEFT) ~= 0 then
    mvx = mvx - rx; mvy = mvy - ry; mvz = mvz - rz
  end
  if engine.input_held(engine.IA.UP) ~= 0 then
    mvy = mvy + 1.0
  end
  if engine.input_held(engine.IA.DOWN) ~= 0 then
    mvy = mvy - 1.0
  end

  if mvx ~= 0.0 or mvy ~= 0.0 or mvz ~= 0.0 then
    local speed = MOVE_SPEED
    -- engine.IA has no SHIFT; the host binds boost separately. Keep it simple
    -- here and use a constant speed (Shift-boost can be added once an input
    -- action is bound for it).
    local step = speed * dt
    local cx, cy, cz = engine.camera_get_pos()
    engine.camera_set_pos(cx + mvx * step, cy + mvy * step, cz + mvz * step)
  end
end
