-- CardHub_Visual.lua : ESP / แสง / ลดแลค / ประหยัดแบต
local H = ...
local Window = H.Window
local RunService, Workspace = H.RunService, H.Workspace
local Lighting = game:GetService("Lighting")

local Page = Window:CreatePage({ Name = "Visual" })
local SecEsp = Page:CreateSection({ Name = "ESP", Side = 1, Collapsed = false })
local SecView = Page:CreateSection({ Name = "View", Side = 2, Collapsed = false })
local SecPerf = Page:CreateSection({ Name = "Performance", Side = 2, Collapsed = false })

local host = (gethui and gethui()) or game:GetService("CoreGui")
local holder = Instance.new("Folder")
holder.Name = "CardHubESP"
pcall(function() holder.Parent = host end)
H.onStop(function() holder:Destroy() end)

local function clearHolder(prefix)
	for _, c in ipairs(holder:GetChildren()) do
		if c.Name:sub(1, #prefix) == prefix then c:Destroy() end
	end
end

----------------------------------------------------------------------
-- ESP: แพ็กที่เก็บได้ในแปลงของเรา
----------------------------------------------------------------------
local function refreshPackEsp()
	clearHolder("pack_")
	if not H.State.EspPacks then return end
	local plot = H.myPlot()
	local root = plot and plot:FindFirstChild("Systems")
	root = root and root:FindFirstChild("PlacedPacks")
	if not root then return end
	for i, d in ipairs(root:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Enabled and d.ActionText == "Collect" then
			local part = d.Parent
			if part and part:IsA("BasePart") then
				local hl = Instance.new("Highlight")
				hl.Name = "pack_" .. i
				hl.Adornee = part
				hl.FillColor = Color3.fromRGB(80, 255, 140)
				hl.FillTransparency = 0.6
				hl.OutlineColor = Color3.fromRGB(255, 255, 255)
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = holder
			end
		end
	end
end
H.toggle(SecEsp, "Pack ESP (my plot)", "EspPacks", false, refreshPackEsp, "ไฮไลต์แพ็กที่กด Collect ได้")
H.loop("EspPacks", function() return 3 end, refreshPackEsp)

----------------------------------------------------------------------
-- ESP: ผู้เล่น + แปลงผู้เล่น
----------------------------------------------------------------------
local function refreshPlayerEsp()
	clearHolder("plr_")
	if not H.State.EspPlayers then return end
	local myHrp = H.hrp()
	for _, p in ipairs(H.Players:GetPlayers()) do
		if p ~= H.lp and p.Character then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local hl = Instance.new("Highlight")
				hl.Name = "plr_hl_" .. p.Name
				hl.Adornee = p.Character
				hl.FillColor = Color3.fromRGB(255, 90, 90)
				hl.FillTransparency = 0.7
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = holder

				local bb = Instance.new("BillboardGui")
				bb.Name = "plr_bb_" .. p.Name
				bb.Adornee = hrp
				bb.Size = UDim2.new(0, 150, 0, 30)
				bb.StudsOffset = Vector3.new(0, 3, 0)
				bb.AlwaysOnTop = true
				local tl = Instance.new("TextLabel", bb)
				tl.Size = UDim2.new(1, 0, 1, 0)
				tl.BackgroundTransparency = 1
				tl.TextColor3 = Color3.new(1, 1, 1)
				tl.TextStrokeTransparency = 0.3
				tl.Font = Enum.Font.GothamBold
				tl.TextSize = 13
				local dist = myHrp and math.floor((myHrp.Position - hrp.Position).Magnitude) or 0
				tl.Text = p.Name .. " [" .. dist .. "]"
				bb.Parent = holder
			end
		end
	end
end
H.toggle(SecEsp, "Player ESP", "EspPlayers", false, refreshPlayerEsp)
H.loop("EspPlayers", function() return 1.5 end, refreshPlayerEsp)

H.toggle(SecEsp, "Show other plots' owners", "EspPlots", false, function(v)
	clearHolder("plot_")
	if not v then return end
	local map = Workspace:FindFirstChild("Map")
	local pm = map and map:FindFirstChild("PlotModels")
	if not pm then return end
	for _, m in ipairs(pm:GetChildren()) do
		local base = m:FindFirstChild("Base", true) or m:FindFirstChild("SpawnPart", true)
		if base and base:IsA("BasePart") then
			local bb = Instance.new("BillboardGui")
			bb.Name = "plot_" .. m.Name
			bb.Adornee = base
			bb.Size = UDim2.new(0, 160, 0, 26)
			bb.StudsOffset = Vector3.new(0, 14, 0)
			bb.AlwaysOnTop = true
			local tl = Instance.new("TextLabel", bb)
			tl.Size = UDim2.new(1, 0, 1, 0)
			tl.BackgroundTransparency = 1
			tl.TextColor3 = Color3.fromRGB(255, 220, 90)
			tl.TextStrokeTransparency = 0.3
			tl.Font = Enum.Font.GothamBold
			tl.TextSize = 14
			tl.Text = m.Name
			bb.Parent = holder
		end
	end
end)

----------------------------------------------------------------------
-- View: Fullbright / No Fog / FOV
----------------------------------------------------------------------
local orig = {
	Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
	GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient,
	FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
}

H.toggle(SecView, "Fullbright", "Fullbright", false, function(v)
	if v then
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(170, 170, 170)
	else
		Lighting.Brightness = orig.Brightness
		Lighting.ClockTime = orig.ClockTime
		Lighting.GlobalShadows = orig.GlobalShadows
		Lighting.Ambient = orig.Ambient
	end
end)

H.toggle(SecView, "No Fog", "NoFog", false, function(v)
	if v then
		Lighting.FogEnd = 1e6
		Lighting.FogStart = 1e6
	else
		Lighting.FogEnd = orig.FogEnd
		Lighting.FogStart = orig.FogStart
	end
end)

local origFov
H.toggle(SecView, "Custom FOV", "FovOn", false, function(v)
	local cam = Workspace.CurrentCamera
	if cam then
		if v then origFov = origFov or cam.FieldOfView else cam.FieldOfView = origFov or 70 end
	end
end)
H.slider(SecView, "FOV", "FovVal", 40, 120, 90, "°")
H.conn(RunService.RenderStepped, function()
	if H.State.FovOn then
		local cam = Workspace.CurrentCamera
		if cam then cam.FieldOfView = H.State.FovVal or 90 end
	end
end)

H.onStop(function()
	pcall(function()
		Lighting.Brightness = orig.Brightness
		Lighting.ClockTime = orig.ClockTime
		Lighting.GlobalShadows = orig.GlobalShadows
		Lighting.Ambient = orig.Ambient
		Lighting.FogEnd = orig.FogEnd
		Lighting.FogStart = orig.FogStart
		if origFov and Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView = origFov end
	end)
end)

----------------------------------------------------------------------
-- Performance
----------------------------------------------------------------------
SecPerf:Button():Add("FPS Booster", function()
	local n = 0
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
			or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
			d.Enabled = false
			n = n + 1
		end
	end
	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		Lighting.GlobalShadows = false
	end)
	H.notify("FPS Booster", "ปิดเอฟเฟกต์ " .. n .. " ชิ้น + ลดคุณภาพภาพ", 4)
end)

-- ประหยัดแบต: ปิดการเรนเดอร์ 3D ทิ้งเครื่องฟาร์มได้นาน
H.toggle(SecPerf, "3D Rendering OFF (battery saver)", "Render3D", false, function(v)
	pcall(function() RunService:Set3dRenderingEnabled(not v) end)
	if v and setfpscap then pcall(setfpscap, H.State.FpsCap or 15) end
	if not v and setfpscap then pcall(setfpscap, 60) end
end, "จอ 3D จะดำ แต่เมนูยังใช้ได้ สคริปยังทำงานปกติ")
H.slider(SecPerf, "FPS cap (when 3D off)", "FpsCap", 5, 60, 15, " fps", function(v)
	if H.State.Render3D and setfpscap then pcall(setfpscap, v) end
end)

H.onStop(function()
	pcall(function() RunService:Set3dRenderingEnabled(true) end)
	if setfpscap then pcall(setfpscap, 60) end
end)

H.toggle(SecPerf, "Hide other players' plots decor", "HideDecor", false, function(v)
	local map = Workspace:FindFirstChild("Map")
	local pm = map and map:FindFirstChild("PlotModels")
	if not pm then return end
	local mine = H.myPlot()
	for _, m in ipairs(pm:GetChildren()) do
		if m ~= mine then
			local decor = m:FindFirstChild("Decor")
			if decor then
				for _, d in ipairs(decor:GetDescendants()) do
					if d:IsA("BasePart") then d.LocalTransparencyModifier = v and 1 or 0 end
				end
			end
		end
	end
end, "ซ่อนของตกแต่งแปลงคนอื่น ลดภาระเครื่อง")
