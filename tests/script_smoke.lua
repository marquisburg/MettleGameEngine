-- Smoke-test script. Runs at chunk-load time AND from on_tick.
engine.log("hello from lua " .. _VERSION)
engine.log("self_id at load = " .. tostring(engine.self_id()))

function on_tick(dt)
  engine.log("on_tick dt=" .. tostring(dt) .. " self=" .. tostring(engine.self_id()))
end
