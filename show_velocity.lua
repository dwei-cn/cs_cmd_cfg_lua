-- 创建 Tab 和 Groupbox
local tabVelocity = gui.Tab(gui.Reference("Visuals"), "velocity_tab", "Velocity Display")
local groupVelocity = gui.Groupbox(tabVelocity, "Velocity Display", 15, 15, 300, 0)

-- 开关、颜色选择器
local velocityEnabled = gui.Checkbox(groupVelocity, "velocity_show", "Show Velocity", true)
local velocityColor = gui.ColorPicker(groupVelocity, "velocity_color", "Text Color", 255, 255, 255, 255)

-- 主绘制函数
callbacks.Register("Draw", function()
    if not velocityEnabled:GetValue() then return end

    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer or not localPlayer:IsAlive() then return end

    local vel = localPlayer:GetPropVector("m_vecVelocity")
    local speed = math.floor(vel:Length2D() + 0.5)

    local screenW, screenH = draw.GetScreenSize()
    local text = "Velocity: " .. speed
    local r, g, b, a = velocityColor:GetValue()

    -- 自动改变颜色
    if speed < 10 then
        r, g, b = 0, 255, 0 -- 绿色
    elseif speed < 120 then
        r, g, b = 255, 255, 0 -- 黄色
    else
        r, g, b = 255, 0, 0 -- 红色
    end

    draw.Color(r, g, b, a)
    draw.Text(screenW - 150, screenH - 100, text)
end)
