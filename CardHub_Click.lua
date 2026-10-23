-- CardHub_Click.lua : ออโต้คลิก (แตะหน้าจอ / กดค้างตำแหน่ง / ใช้ไอเท็มในมือ)
local H = ...
local Window = H.Window
local UIS = H.UIS
local Workspace = H.Workspace

local Page = Window:CreatePage({ Name = "Click" })
local SecMain = Page:CreateSection({ Name = "Auto Click", Side = 1, Collapsed = false })
local SecOpt  = Page:CreateSection({ Name = "Options", Side = 2, Collapsed = false })

local clickPos = nil      -- Vector2 (พิกัด viewport)
local capturing = false
local posLabel

----------------------------------------------------------------------
-- ตัวคลิก
----------------------------------------------------------------------
local function targetPoint()
	local mode = H.State.ClickMode
	if mode == "Custom Position" and clickPos then
		return clickPos
	elseif mode == "Follow Cursor" then
		return UIS:GetMouseLocation()
	end
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(800, 400)
	return Vector2.new(vp.X / 2, vp.Y / 2)
end

local clicksDone = 0
local toggleObj

local function doClick()
	local mode = H.State.ClickMode
	if mode == "Tool Activate" then
		local c = H.char()
		local tool = c and c:FindFirstChildOfClass("Tool")
		if tool then pcall(function() tool:Activate() end) end
		H.Stats.Clicks = H.Stats.Clicks + 1
		clicksDone = clicksDone + 1
		return
	end
	local p = targetPoint()
	local j = H.State.ClickJitter or 0
	local x = p.X + (j > 0 and math.random(-j, j) or 0)
	local y = p.Y + (j > 0 and math.random(-j, j) or 0)
	H.tapAt(x, y, H.State.ClickInput)
	H.Stats.Clicks = H.Stats.Clicks + 1
	clicksDone = clicksDone + 1
end

----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------
toggleObj = H.toggle(SecMain, "Auto Click", "AutoClick", false, function(v)
	if v then clicksDone = 0 end
end, "คลิกซ้ำตามความเร็ว (CPS) ที่ตั้งไว้")

H.slider(SecMain, "Clicks per second", "ClickCPS", 1, 30, 8, " cps")
H.dropdown(SecMain, "Click mode", "ClickMode",
	{ "Screen Center", "Custom Position", "Follow Cursor", "Tool Activate" }, "Screen Center", false)
H.dropdown(SecMain, "Input type", "ClickInput", { "Touch", "Mouse" },
	H.IsMobile and "Touch" or "Mouse", false)

posLabel = SecMain:Label("Position: not set")

SecMain:Button():Add("Set Position (tap in 3s)", function()
	if capturing then return end
	capturing = true
	H.notify("Auto Click", "ปิดเมนู (ปุ่มลอย) แล้วแตะตำแหน่งที่ต้องการภายใน 6 วินาที", 6)
	local got
	local conn
	conn = UIS.InputBegan:Connect(function(input, gp)
		if input.UserInputType == Enum.UserInputType.Touch then
			local inset = H.GuiService:GetGuiInset()
			got = Vector2.new(input.Position.X, input.Position.Y + inset.Y)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			got = UIS:GetMouseLocation()
		end
		if got then conn:Disconnect() end
	end)
	task.delay(3, function()
		-- รอจนแตะ หรือครบเวลา
		local t = os.clock()
		while not got and os.clock() - t < 3 do task.wait(0.1) end
		pcall(function() conn:Disconnect() end)
		capturing = false
		if got then
			clickPos = got
			pcall(function() posLabel:SetText(("Position: %d, %d"):format(got.X, got.Y)) end)
			H.notify("Auto Click", "บันทึกตำแหน่งแล้ว", 3)
		else
			H.notify("Auto Click", "ไม่ได้รับการแตะ ลองใหม่", 3)
		end
	end)
end):Add("Use Center", function()
	clickPos = nil
	pcall(function() posLabel:SetText("Position: not set") end)
end)

H.slider(SecOpt, "Random jitter", "ClickJitter", 0, 12, 0, " px")
H.slider(SecOpt, "Humanize timing", "ClickHuman", 0, 60, 10, "%")
H.slider(SecOpt, "Stop after clicks (0 = never)", "ClickLimit", 0, 5000, 0, "")
H.toggle(SecOpt, "Pause while menu is open", "ClickPauseMenu", false, nil,
	"หยุดคลิกขณะเมนูเปิด กันคลิกโดนปุ่มของเมนูเอง")

SecOpt:Label({
	Name = "Tip",
	Description = "ตั้งตำแหน่งคลิกให้อยู่นอกเมนู หรือปิดเมนูด้วยปุ่มลอยหลังกดเปิด Auto Click",
})

-- ปุ่มลัดสำหรับคีย์บอร์ด (Delta บนมือถือใช้สวิตช์ในเมนูแทน)
local hk = SecOpt:Label("Toggle Auto Click key")
hk:Hotkey({
	Flag = "AutoClickKey", Default = Enum.KeyCode.F6, Mode = "Click",
	Callback = function()
		pcall(function() toggleObj:SetValue(not H.State.AutoClick) end)
	end,
})

----------------------------------------------------------------------
-- ลูปหลัก (ปรับเวลาเองเพราะ CPS สูง)
----------------------------------------------------------------------
task.spawn(function()
	while H.Alive do
		if H.State.AutoClick then
			local limit = H.State.ClickLimit or 0
			if limit > 0 and clicksDone >= limit then
				pcall(function() toggleObj:SetValue(false) end)
				H.State.AutoClick = false
				H.notify("Auto Click", "คลิกครบ " .. limit .. " ครั้งแล้ว", 3)
			else
				local menuOpen = false
				if H.State.ClickPauseMenu then
					pcall(function() menuOpen = H.Library.Menu and H.Library.Menu.Open end)
				end
				if not menuOpen then
					local ok, e = pcall(doClick)
					if not ok then H.err("click", e) end
				end
			end
			local base = 1 / math.max(1, H.State.ClickCPS or 8)
			local h = (H.State.ClickHuman or 0) / 100
			task.wait(math.max(0.02, base * (1 + (math.random() * 2 - 1) * h)))
		else
			task.wait(0.25)
		end
	end
end)
