--[[
	CardHub_Click.lua : หน้า "คลิก" (ออโต้คลิก: แตะกลางจอ / แตะตำแหน่งที่ตั้งไว้ / ตามเมาส์ / ใช้ไอเท็มในมือ)

	โหลดโดย CardHub.lua และรับตัวกลาง H ผ่าน `local H = ...`
	ค่าที่ผู้ใช้ตั้งทั้งหมดอยู่ใน H.State เช่น H.State.ClickCPS, H.State.ClickMode
]]

local H = ...
local Window = H.Window
local UIS = H.UIS
local Workspace = H.Workspace

local Page = Window:CreatePage({ Name = "คลิก" })
local SecMain = Page:CreateSection({ Name = "ออโต้คลิก", Side = 1, Collapsed = false })
local SecOpt  = Page:CreateSection({ Name = "ตัวเลือก", Side = 2, Collapsed = false })

local clickPos = nil      -- ตำแหน่งที่ผู้ใช้ตั้งไว้ (Vector2 เป็นพิกเซลบนหน้าจอ) nil = ยังไม่ตั้ง
local capturing = false   -- true ระหว่างรอผู้ใช้แตะเลือกตำแหน่ง (กันกดซ้อน)
local posLabel            -- ป้ายแสดงตำแหน่งที่ตั้งไว้

----------------------------------------------------------------------
-- ตัวคลิก
-- โหมดคลิก (ค่าในดรอปดาวน์ต้องตรงกับที่เทียบในโค้ดด้านล่างเป๊ะ ๆ):
--   "กลางจอ"            แตะกลางหน้าจอ
--   "ตำแหน่งที่ตั้งไว้"   แตะจุดที่กดปุ่ม "ตั้งตำแหน่ง"
--   "ตามเมาส์"          แตะที่ตำแหน่งเมาส์ตอนนั้น
--   "ใช้ไอเท็มในมือ"      สั่ง Tool ที่ถืออยู่ทำงาน (เหมือนคลิกซ้ายตอนถือของ)
----------------------------------------------------------------------
local MODE_CENTER, MODE_CUSTOM, MODE_CURSOR, MODE_TOOL =
	"กลางจอ", "ตำแหน่งที่ตั้งไว้", "ตามเมาส์", "ใช้ไอเท็มในมือ"

-- คืนพิกัดที่จะคลิกตามโหมดที่เลือก
local function targetPoint()
	local mode = H.State.ClickMode
	if mode == MODE_CUSTOM and clickPos then
		return clickPos
	elseif mode == MODE_CURSOR then
		return UIS:GetMouseLocation()
	end
	-- โหมดอื่น/ยังไม่ได้ตั้งตำแหน่ง -> ใช้กลางจอ
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(800, 400)
	return Vector2.new(vp.X / 2, vp.Y / 2)
end

local clicksDone = 0 -- จำนวนคลิกในรอบนี้ ใช้เทียบกับ "หยุดหลังกี่ครั้ง"
local toggleObj      -- เก็บสวิตช์ไว้ เพื่อสั่งปิดจากโค้ดได้ (ตอนคลิกครบ/ใช้ปุ่มลัด)

-- คลิกหนึ่งครั้ง
local function doClick()
	local mode = H.State.ClickMode
	if mode == MODE_TOOL then
		local c = H.char()
		local tool = c and c:FindFirstChildOfClass("Tool") -- Tool ที่ถืออยู่จะอยู่ใต้ตัวละคร
		if tool then pcall(function() tool:Activate() end) end
		H.Stats.Clicks = H.Stats.Clicks + 1
		clicksDone = clicksDone + 1
		return
	end
	local p = targetPoint()
	local j = H.State.ClickJitter or 0 -- ความสุ่มของพิกัด (พิกเซล) ให้ดูไม่ซ้ำจุดเดิมเป๊ะ
	local x = p.X + (j > 0 and math.random(-j, j) or 0)
	local y = p.Y + (j > 0 and math.random(-j, j) or 0)
	-- ClickInput ต้องเป็น "Touch" หรือ "Mouse" ตามที่ H.tapAt รองรับ (เก็บเป็นอังกฤษไว้ใช้ภายใน)
	H.tapAt(x, y, H.State.ClickInput)
	H.Stats.Clicks = H.Stats.Clicks + 1
	clicksDone = clicksDone + 1
end

----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------
-- callback รับ v (true/false) : ตอนเปิดให้รีเซ็ตตัวนับคลิกเป็น 0
toggleObj = H.toggle(SecMain, "ออโต้คลิก", "AutoClick", false, function(v)
	if v then clicksDone = 0 end
end, "คลิกซ้ำตามความเร็ว (CPS) ที่ตั้งไว้")

H.slider(SecMain, "คลิกต่อวินาที", "ClickCPS", 1, 30, 8, " ครั้ง/วิ")
H.dropdown(SecMain, "โหมดคลิก", "ClickMode",
	{ MODE_CENTER, MODE_CUSTOM, MODE_CURSOR, MODE_TOOL }, MODE_CENTER, false)
-- "Touch" = แตะนิ้ว (มือถือ) / "Mouse" = คลิกเมาส์ (คอม) เลือกค่าเริ่มต้นตามอุปกรณ์ให้เอง
H.dropdown(SecMain, "ชนิดอินพุต (Touch=แตะ, Mouse=เมาส์)", "ClickInput", { "Touch", "Mouse" },
	H.IsMobile and "Touch" or "Mouse", false)

posLabel = SecMain:Label("ตำแหน่ง: ยังไม่ได้ตั้ง")

-- ปุ่มตั้งตำแหน่ง: เริ่มดักจับการแตะ/คลิกครั้งถัดไปของผู้ใช้
SecMain:Button():Add("ตั้งตำแหน่ง (แตะภายใน 3 วิ)", function()
	if capturing then return end
	capturing = true
	H.notify("ออโต้คลิก", "ปิดเมนู (ปุ่มลอย) แล้วแตะตำแหน่งที่ต้องการภายใน 6 วินาที", 6)
	local got  -- พิกัดที่จับได้
	local conn
	conn = UIS.InputBegan:Connect(function(input, gp)
		if input.UserInputType == Enum.UserInputType.Touch then
			-- พิกัดสัมผัสไม่รวมแถบบนสุดของ Roblox จึงบวก GuiInset.Y ชดเชยให้ตรงกับพิกัด viewport
			local inset = H.GuiService:GetGuiInset()
			got = Vector2.new(input.Position.X, input.Position.Y + inset.Y)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			got = UIS:GetMouseLocation()
		end
		if got then conn:Disconnect() end -- ได้ค่าแล้วเลิกดักจับ
	end)
	task.delay(3, function()
		-- รอจนแตะ หรือครบเวลา
		local t = os.clock()
		while not got and os.clock() - t < 3 do task.wait(0.1) end
		pcall(function() conn:Disconnect() end)
		capturing = false
		if got then
			clickPos = got
			pcall(function() posLabel:SetText(("ตำแหน่ง: %d, %d"):format(got.X, got.Y)) end)
			H.notify("ออโต้คลิก", "บันทึกตำแหน่งแล้ว", 3)
		else
			H.notify("ออโต้คลิก", "ไม่ได้รับการแตะ ลองใหม่", 3)
		end
	end)
end):Add("ใช้กลางจอ", function()
	-- ต่อปุ่มที่สองในแถวเดียวกันด้วย :Add(...) ล้างตำแหน่งที่ตั้งไว้
	clickPos = nil
	pcall(function() posLabel:SetText("ตำแหน่ง: ยังไม่ได้ตั้ง") end)
end)

H.slider(SecOpt, "สุ่มขยับตำแหน่ง", "ClickJitter", 0, 12, 0, " px")
H.slider(SecOpt, "สุ่มจังหวะให้เหมือนคน", "ClickHuman", 0, 60, 10, "%")
H.slider(SecOpt, "หยุดหลังคลิกครบ (0 = ไม่หยุด)", "ClickLimit", 0, 5000, 0, "")
H.toggle(SecOpt, "หยุดคลิกตอนเมนูเปิด", "ClickPauseMenu", false, nil,
	"หยุดคลิกขณะเมนูเปิด กันคลิกโดนปุ่มของเมนูเอง")

SecOpt:Label({
	Name = "เคล็ดลับ",
	Description = "ตั้งตำแหน่งคลิกให้อยู่นอกเมนู หรือปิดเมนูด้วยปุ่มลอยหลังกดเปิดออโต้คลิก",
})

-- ปุ่มลัดสำหรับคีย์บอร์ด (บนมือถือใช้สวิตช์ในเมนูแทน)
local hk = SecOpt:Label("ปุ่มลัดเปิด/ปิดออโต้คลิก")
hk:Hotkey({
	Flag = "AutoClickKey", Default = Enum.KeyCode.F6, Mode = "Click",
	Callback = function()
		-- สลับค่าสวิตช์ (กลับจากค่าปัจจุบัน)
		pcall(function() toggleObj:SetValue(not H.State.AutoClick) end)
	end,
})

----------------------------------------------------------------------
-- ลูปหลัก (เขียนเองแทน H.loop เพราะ CPS สูงต้องคุมเวลารอละเอียด + มีสุ่มจังหวะ)
----------------------------------------------------------------------
task.spawn(function()
	while H.Alive do
		if H.State.AutoClick then
			local limit = H.State.ClickLimit or 0
			if limit > 0 and clicksDone >= limit then
				-- คลิกครบจำนวนที่ตั้ง -> ปิดสวิตช์เอง
				pcall(function() toggleObj:SetValue(false) end)
				H.State.AutoClick = false
				H.notify("ออโต้คลิก", "คลิกครบ " .. limit .. " ครั้งแล้ว", 3)
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
			-- เวลารอ = 1/CPS แล้วสุ่มเพิ่ม/ลดตามเปอร์เซ็นต์ ClickHuman (ขั้นต่ำ 0.02 วิ)
			local base = 1 / math.max(1, H.State.ClickCPS or 8)
			local h = (H.State.ClickHuman or 0) / 100
			task.wait(math.max(0.02, base * (1 + (math.random() * 2 - 1) * h)))
		else
			task.wait(0.25) -- ปิดอยู่: เช็กสวิตช์ทุก 0.25 วิ ไม่กินเครื่อง
		end
	end
end)
