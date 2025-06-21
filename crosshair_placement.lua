-- 创建 Tab 和 Groupbox
local tabCrosshair = gui.Tab(gui.Reference("Visuals"), "crosshair_tab", "Crosshair Line")
local groupCrosshair = gui.Groupbox(tabCrosshair, "Crosshair Line Settings", 15, 15, 300, 0)

local crosshairEnabled = gui.Checkbox(groupCrosshair, "crosshair_show", "Show Crosshair Line", true)
local crosshairLength = gui.Slider(groupCrosshair, "crosshair_length", "Line Length", 2500, 10, 5000)
local crosshairThickness = gui.Slider(groupCrosshair, "crosshair_thickness", "Line Thickness", 45, 1, 80)
local showAng = gui.Checkbox(groupCrosshair, "crosshair_showang", "Use Pitch to Color Line", true)

local stage1Threshold = gui.Slider(groupCrosshair, "crosshair_stage1_thresh", "Stage 1 Max (°)", 0.5, 0.5, 10)
local stage2Threshold = gui.Slider(groupCrosshair, "crosshair_stage2_thresh", "Stage 2 Max (°)", 1.5, 0.5, 20)

local alphaStage1 = gui.Slider(groupCrosshair, "crosshair_alpha_stage1", "Stage 1 Alpha", 30, 0, 255)
local alphaStage2 = gui.Slider(groupCrosshair, "crosshair_alpha_stage2", "Stage 2 Alpha", 0, 0, 255)
local alphaStage3 = gui.Slider(groupCrosshair, "crosshair_alpha_stage3", "Stage 3 Alpha", 0, 0, 0)

local showPitch = gui.Checkbox(groupCrosshair, "crosshair_showpitch", "Show Pitch Value", false)

-- 一键归零按键（默认 9 键）
local setPitchZeroKey = gui.Keybox(groupCrosshair, "crosshair_pitchzero_key", "Set Pitch to 0 Key", 0x30 + 9) -- 默认数字 9 键

-- Smoothing 参数
local smoothingSpeed = gui.Slider(groupCrosshair, "pitch_smooth_speed", "Smoothing Speed", 0.5, 0.1, 2)

-- Smoothing 状态
local isSmoothing = false

callbacks.Register("Draw", function()
    if not crosshairEnabled:GetValue() then return end

    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer or not localPlayer:IsAlive() then return end

    local screenW, screenH = draw.GetScreenSize()
    local centerX = math.floor(screenW / 2)
    local centerY = math.floor(screenH / 2)
    local lineLength = crosshairLength:GetValue()
    local thickness = crosshairThickness:GetValue()

    local ang = 0
    if showAng:GetValue() or showPitch:GetValue() then
        local viewAngles = engine.GetViewAngles()
        ang = viewAngles.x or 0
    end

    local absAng = math.abs(ang)
    local stage1 = stage1Threshold:GetValue()
    local stage2 = stage2Threshold:GetValue()

    local r, g, b, a = 0, 255, 0, 0

    if absAng <= stage1 then
        a = alphaStage1:GetValue()
    elseif absAng <= stage2 then
        a = alphaStage2:GetValue()
    else
        a = alphaStage3:GetValue()
    end

    draw.Color(r, g, b, a)
    local x1 = centerX - math.floor(lineLength / 2)
    local y1 = centerY - math.floor(thickness / 2)
    local x2 = centerX + math.floor(lineLength / 2)
    local y2 = centerY + math.floor(thickness / 2)
    draw.FilledRect(x1, y1, x2, y2)

    if showPitch:GetValue() then
        draw.Color(255, 255, 255, 255)
        draw.Text(centerX - 30, centerY + 20 + thickness, string.format("Pitch: %.2f", ang))
    end
end)

-- 平滑归零逻辑
callbacks.Register("CreateMove", function(cmd)
    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer or not localPlayer:IsAlive() then return end

    local key = setPitchZeroKey:GetValue()
    local viewAngles = engine.GetViewAngles()

    -- 检测按键
    if key ~= 0 and input.IsButtonDown(key) then
        isSmoothing = true
    end

    if isSmoothing then
        local pitch = viewAngles.x
        local smoothing = smoothingSpeed:GetValue()

        if math.abs(pitch) < 0.01 then
            isSmoothing = false
            return
        end

        -- 平滑调整
        local newPitch = pitch - (pitch / math.abs(pitch)) * smoothing

        -- 如果即将超过 0，直接归零，防止来回震荡
        if (pitch > 0 and newPitch < 0) or (pitch < 0 and newPitch > 0) then
            newPitch = 0
            isSmoothing = false
        end

        viewAngles.x = newPitch
        cmd.viewangles = viewAngles
        engine.SetViewAngles(viewAngles)
    end
end)
