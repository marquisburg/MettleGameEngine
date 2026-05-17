-- Spinner: rotates the bound entity around the Y axis at 1.3 rad/s.
-- Drop a cube into the scene, select it, click a `.lua` in the Assets panel,
-- and press Ctrl+L to bind this script. Then press F5 to enter play mode.
function on_tick(dt)
  engine.rotate_world(2, dt * 1.3)
end
