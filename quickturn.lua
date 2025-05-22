local tab = gui.Tab(gui.Reference("Visuals"), "quickturn.tab", "Quick Turn")

local box = gui.Groupbox(tab, "Quick Turn Settings", 16, 16, 260, 170)
local enable = gui.Checkbox(box, "quickturn.enable", "Enable Quick Turn", True) 
local keybox_left = gui.Keybox(box, "quickturn.leftkey", "Turn Right Key", 0) 
local keybox_right = gui.Keybox(box, "quickturn.rightkey", "Turn Left Key", 0) 
local step_slider = gui.Slider(box, "quickturn.stepsize", "Angle Per Frame", 1, 0, 5)
local total_slider = gui.Slider(box, "quickturn.totalangle", "Total Turn Angle", 10, 0, 45)
gui.Text(box, "Tip: Mouse wheel up is 0x20, down is 0x21")

local turning = false
local direction = 0 -- -1 for left, 1 for right
local rotated = 0

local function normalize_yaw(yaw)
    while yaw < -180 do yaw = yaw + 360 end
    while yaw > 180 do yaw = yaw - 360 end
    return yaw
end

callbacks.Register("Draw", function()
    if not enable:GetValue() then return end

    local localplayer = entities.GetLocalPlayer()
    if not localplayer or not localplayer:IsAlive() then return end

    local viewangles = engine.GetViewAngles()
    local left_key = keybox_left:GetValue()
    local right_key = keybox_right:GetValue()
    local step = step_slider:GetValue()
    local total = total_slider:GetValue()

    -- Start rotating
    if not turning then
        if left_key ~= 0 and input.IsButtonPressed(left_key) then
            turning = true
            direction = -1
            rotated = 0
        elseif right_key ~= 0 and input.IsButtonPressed(right_key) then
            turning = true
            direction = 1
            rotated = 0
        end
    end

    -- Perform incremental turn
    if turning then
        local delta = math.min(step, total - rotated)
        local new_yaw = normalize_yaw(viewangles.y + delta * direction)
        engine.SetViewAngles(EulerAngles(viewangles.x, new_yaw, viewangles.z))
        rotated = rotated + delta

        if rotated >= total then
            turning = false
        end
    end
end)
