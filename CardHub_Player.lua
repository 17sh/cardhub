-- CardHub_Player.lua : ตัวละคร (ความเร็ว / กระโดด / noclip / บิน / กัน AFK)
local H = ...
local Window = H.Window
local UIS, RunService, Workspace = H.UIS, H.RunService, H.Workspace

local Page = Window:CreatePage({ Name = "Player" })
local SecMove = Page:CreateSection({ Name = "Movement", Side = 1, Collapsed = false })
local SecSafe = Page:CreateSection({ Name = "Utility", Side = 2, Collapsed = false })

----------------------------------------------------------------------
-- Speed / Jump
----------------------------------------------------------------------
H.toggle(SecMove, "WalkSpeed", "SpeedOn", false, function(v)
	if not v then
		local hum = H.hum()
		if hum then hum.WalkSpeed = 16 end
	end
end)
H.slider(SecMove, "Speed value", "SpeedVal", 16, 150, 40, "")

H.toggle(SecMove, "JumpPower", "JumpOn", false, function(v)
	if not v then
		local hum = H.hum()
		if hum then hum.JumpPower = 50 end
	end
end)
H.slider(SecMove, "Jump value", "JumpVal", 50, 250, 90, "")

H.conn(RunService.Heartbeat, function()
	local hum = H.hum()
	if not hum then return end
	if H.State.SpeedOn then hum.WalkSpeed = H.State.SpeedVal or 40 end
	if H.State.JumpOn then
		hum.UseJumpPower = true
		hum.JumpPower = H.State.JumpVal or 90
	end
end)

----------------------------------------------------------------------
-- Infinite Jump
----------------------------------------------------------------------
H.toggle(SecMove, "Infinite Jump", "InfJump", false)
H.conn(UIS.JumpRequest, function()
	if H.State.InfJump then
		local hum = H.hum()
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

----------------------------------------------------------------------
-- Noclip
----------------------------------------------------------------------
H.toggle(SecMove, "Noclip", "Noclip", false)
H.conn(RunService.Stepped, function()
	if not H.State.Noclip then return end
	local c = H.char()
	if not c then return end
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
	end
end)

----------------------------------------------------------------------
-- Fly (ดันไปทางที่กล้องมอง ใช้จอยเดินปกติ)
----------------------------------------------------------------------
local flyBV, flyBG

local function stopFly()
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
	local hum = H.hum()
	if hum then hum.PlatformStand = false end
end

H.toggle(SecMove, "Fly", "Fly", false, function(v)
	if v then
		local hrp, hum = H.hrp(), H.hum()
		if not (hrp and hum) then return end
		stopFly()
		flyBV = Instance.new("BodyVelocity")
		flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
		flyBV.Velocity = Vector3.zero
		flyBV.Parent = hrp
		flyBG = Instance.new("BodyGyro")
		flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
		flyBG.P = 9e4
		flyBG.CFrame = hrp.CFrame
		flyBG.Parent = hrp
		hum.PlatformStand = true
	else
		stopFly()
	end
end, "ดันจอยไปข้างหน้าเพื่อบินไปทางที่กล้องมอง")
H.slider(SecMove, "Fly speed", "FlySpeed", 20, 200, 70, "")

H.conn(RunService.RenderStepped, function()
	if not (H.State.Fly and flyBV and flyBV.Parent) then return end
	local hum, cam = H.hum(), Workspace.CurrentCamera
	if not (hum and cam) then return end
	local md = hum.MoveDirection
	if md.Magnitude < 0.05 then
		flyBV.Velocity = Vector3.zero
	else
		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		local rightV = cam.CFrame.RightVector
		local flatR = Vector3.new(rightV.X, 0, rightV.Z)
		local f = flat.Magnitude > 0 and md:Dot(flat.Unit) or 0
		local r = flatR.Magnitude > 0 and md:Dot(flatR.Unit) or 0
		flyBV.Velocity = (look * f + rightV * r) * (H.State.FlySpeed or 70)
	end
	if flyBG then flyBG.CFrame = cam.CFrame end
end)

H.onStop(function()
	stopFly()
	local hum = H.hum()
	if hum then hum.WalkSpeed = 16 hum.JumpPower = 50 end
end)

-- เกิดใหม่แล้วปิดบินให้ (กันค้าง)
H.conn(H.lp.CharacterAdded, function()
	flyBV, flyBG = nil, nil
end)

----------------------------------------------------------------------
-- Anti-AFK (เปิดตั้งแต่แรก)
----------------------------------------------------------------------
local VU
pcall(function() VU = game:GetService("VirtualUser") end)

H.toggle(SecSafe, "Anti-AFK", "AntiAFK", true, nil, "กันถูกเตะเมื่อไม่ขยับ 20 นาที")
H.conn(H.lp.Idled, function()
	if not H.State.AntiAFK then return end
	pcall(function()
		if VU then
			VU:CaptureController()
			VU:ClickButton2(Vector2.new())
		elseif H.VIM then
			H.VIM:SendMouseButtonEvent(0, 0, 1, true, game, 1)
			task.wait(0.05)
			H.VIM:SendMouseButtonEvent(0, 0, 1, false, game, 1)
		end
	end)
end)

-- ขยับตัวเล็กน้อยทุก 60 วิ เป็นตัวช่วยเสริม
H.toggle(SecSafe, "Tiny movement every 60s", "AFKMove", false)
task.spawn(function()
	while H.Alive do
		task.wait(60)
		if H.State.AFKMove then
			local hum = H.hum()
			if hum then hum:Move(Vector3.new(0, 0, -1), true) task.wait(0.25) hum:Move(Vector3.zero, true) end
		end
	end
end)

SecSafe:Button():Add("Reset Character", function()
	local hum = H.hum()
	if hum then hum.Health = 0 end
end):Add("Sit/Stand", function()
	local hum = H.hum()
	if hum then hum.Sit = not hum.Sit end
end)

SecSafe:Label({
	Name = "Tip",
	Description = "ค่าความเร็ว/กระโดดที่สูงมากอาจถูกระบบตรวจจับของเกม แนะนำไม่เกิน 40-60",
})
