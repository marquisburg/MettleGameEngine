-- LocalScript example: reads input on client
function on_tick(dt)
  if engine.input_pressed(engine.IA.FIRE) ~= 0 then
    engine.log("client fired")
  end
end
