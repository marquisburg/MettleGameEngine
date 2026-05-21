-- LocalScript: fly camera + WASD movement controller (playtest client).
--
-- Mouse drives camera yaw/pitch. WASD moves the script's *self* entity along
-- the camera-relative horizontal plane (so forward is always "where you look",
-- projected onto the ground). Space/Ctrl move the entity up/down in world
-- space. The camera tracks the entity at a fixed eye offset, so moving the
-- entity also moves the view. this gives a first-person feel without needing
-- a separate "attach camera to entity" API.
--
-- Controls (defaults from engine InputMap):
--   Mouse     look (yaw / pitch)
--   W S       forward / back along view (horizontal)
--   A D       strafe left / right (horizontal)
--   Space     up
--   Ctrl      down
--
-- Position is in metres.

local LOOK_SENS   = 0.0035  -- radians per mouse pixel
local MOVE_SPEED  = 8.0     -- metres per second
local PITCH_LIMIT = 1.50    -- mirrors engine_viewport_cam_set_look's clamp

local _prev = {}

local function normalize_xz(x, z)
  local len = math.sqrt(x * x + z * z)
  if len < 1e-6 then return 0.0, 0.0 end
  return x / len, z / len
end

function on_tick(dt)
  -- Mouse-look. Read the engine's authoritative yaw/pitch so we never drift
  -- past the engine's clamp.
  local yaw, pitch = engine.camera_get_look()
  local dx, dy = engine.mouse_delta()
  if dx ~= 0 or dy ~= 0 then
    yaw = yaw + dx * LOOK_SENS
    pitch = pitch - dy * LOOK_SENS
    if pitch < -PITCH_LIMIT then pitch = -PITCH_LIMIT end
    if pitch >  PITCH_LIMIT then pitch =  PITCH_LIMIT end
    engine.camera_set_look(yaw, pitch)
  end

  -- Horizontal basis: project camera forward/right onto the XZ plane so
  -- looking up/down doesn't make the character fly.
  local fx, _, fz = engine.camera_forward()
  local rx, _, rz = engine.camera_right()
  fx, fz = normalize_xz(fx, fz)
  rx, rz = normalize_xz(rx, rz)

  local mvx, mvy, mvz = 0.0, 0.0, 0.0
  local hF = engine.input_held(engine.IA.FORWARD)
  local hB = engine.input_held(engine.IA.BACK)
  local hL = engine.input_held(engine.IA.LEFT)
  local hR = engine.input_held(engine.IA.RIGHT)
  local hU = engine.input_held(engine.IA.UP)
  local hD = engine.input_held(engine.IA.DOWN)

  if hF then
    mvx = mvx + fx
    mvz = mvz + fz
  end
  if hB then
    mvx = mvx - fx
    mvz = mvz - fz
  end
  if hR then
    mvx = mvx + rx
    mvz = mvz + rz
  end
  if hL then
    mvx = mvx - rx
    mvz = mvz - rz
  end
  if hU then mvy = mvy + 1.0 end
  if hD then mvy = mvy - 1.0 end

  -- ClientScripts run with no owner entity (self_id == 0 until the
  -- player-entity binding gap lands), so engine.translate / engine.get_pos
  -- silently no-op. Drive the camera position directly instead.
  if mvx ~= 0.0 or mvy ~= 0.0 or mvz ~= 0.0 then
    local step = MOVE_SPEED * dt
    local cx, cy, cz = engine.camera_get_pos()
    engine.camera_set_pos(cx + mvx * step, cy + mvy * step, cz + mvz * step)
  end
end
