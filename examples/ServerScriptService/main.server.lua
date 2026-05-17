-- ServerScript example: spins the first cube on the server.
local t = 0
function on_tick(dt)
  t = t + dt
  local e = game:GetService("Workspace"):FindFirstChild("Cube 1")
  if e then
    e.CFrame = e.CFrame * CFrame.Angles(0, dt * 1.5, 0)
  end
end
