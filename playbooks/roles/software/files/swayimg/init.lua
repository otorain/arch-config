-- Swayimg config: layered over the compiled-in defaults, so only the
-- differences below are listed.

-- Info overlay hidden at startup; `t` (default binding) toggles it.
swayimg.text.visible = false

-- Wheel panning: each event adds velocity to the viewport, which decays
-- exponentially into a short inertial glide. Wheel-up reveals content above,
-- matching the arrow-key defaults.
local IMPULSE = 900   -- px/s added per wheel event
local MAX_V   = 4500  -- px/s velocity cap
local TAU     = 0.16  -- velocity decay time constant, s
local DT      = 0.016 -- animation tick, s
local MIN_V   = 15    -- glide stops below this speed, px/s

local vx, vy, running = 0, 0, false

local function stop_pan()
    vx, vy, running = 0, 0, false
end

local function round(v)
    if v >= 0 then
        return math.floor(v + 0.5)
    end
    return math.ceil(v - 0.5)
end

local function limit(v)
    return math.max(-MAX_V, math.min(MAX_V, v))
end

local function tick()
    if swayimg.mode ~= "viewer" then
        stop_pan()
        return
    end
    local pos = swayimg.viewer.get_position()
    swayimg.viewer.set_abs_position(pos.x + round(vx * DT),
        pos.y + round(vy * DT))
    vx = vx * math.exp(-DT / TAU)
    vy = vy * math.exp(-DT / TAU)
    if math.abs(vx) < MIN_V and math.abs(vy) < MIN_V then
        stop_pan()
        return
    end
    swayimg.defer(DT, tick)
end

local function pan(dx, dy)
    vx = limit(vx + dx)
    vy = limit(vy + dy)
    if not running then
        running = true
        swayimg.defer(DT, tick)
    end
end

swayimg.viewer.on_mouse("ScrollUp", function() pan(0, IMPULSE) end)
swayimg.viewer.on_mouse("ScrollDown", function() pan(0, -IMPULSE) end)
swayimg.viewer.on_mouse("ScrollLeft", function() pan(IMPULSE, 0) end)
swayimg.viewer.on_mouse("ScrollRight", function() pan(-IMPULSE, 0) end)

-- A glide must not carry over to the next image.
swayimg.viewer.on_image_change(stop_pan)
