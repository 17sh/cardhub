-- CardHub_Auto.lua : ระบบออโต้ (เก็บแพ็ก / เงินการ์ด / รางวัล / กดปุ่ม GUI)
local H = ...
local Window = H.Window
local PlayerGui = H.lp:WaitForChild("PlayerGui")

local Page = Window:CreatePage({ Name = "Auto" })
local SecCollect = Page:CreateSection({ Name = "Collect", Side = 1, Collapsed = false })
local SecReward  = Page:CreateSection({ Name = "Rewards & GUI", Side = 2, Collapsed = false })

----------------------------------------------------------------------
-- 1) Auto Collect Packs (ProximityPrompt "Collect" ในแปลงของเรา)
----------------------------------------------------------------------
local lastFire = setmetatable({}, { __mode = "k" })

local function getCollectPrompts()
	local plot = H.myPlot()
	if not plot then return {}, false end
	local root = plot:FindFirstChild("Systems")
	root = root and root:FindFirstChild("PlacedPacks") or plot
	local out = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Enabled and d.ActionText == "Collect" then
			out[#out + 1] = d
		end
	end
	return out, true
end

local warnedNoPlot = false
local function collectAll()
	local prompts, found = getCollectPrompts()
	if not found then
		if not warnedNoPlot then
			warnedNoPlot = true
			H.notify("Auto Collect", "หาแปลงของคุณไม่เจอ (Map.PlotModels." .. H.lp.Name .. ")", 5)
		end
		return
	end
	warnedNoPlot = false
	local hrp = H.hrp()
	if not hrp then return end

	local now = os.clock()
	local home, moved
	for _, p in ipairs(prompts) do
		if H.State.CollectPerPrompt and lastFire[p] and now - lastFire[p] < H.State.CollectPerPrompt then
			-- ข้าม: เพิ่งกดไป
		else
			local pos = H.promptPos(p)
			if pos then
				local far = (hrp.Position - pos).Magnitude > ((p.MaxActivationDistance or 10) - 1.5)
				if far and H.State.WalkNear then
					home = home or hrp.CFrame
					hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3.2, 0))
					moved = true
					task.wait(0.12)
				end
				H.press(p)
				lastFire[p] = os.clock()
				H.Stats.Collected = H.Stats.Collected + 1
				task.wait(0.05)
			end
		end
	end
	if moved and home and H.State.ReturnBack then
		task.wait(0.05)
		local h2 = H.hrp()
		if h2 then h2.CFrame = home end
	end
end

H.toggle(SecCollect, "Auto Collect Packs", "AutoCollect", false, nil,
	"กด Collect ทุกแพ็กในแปลงของคุณ")
H.slider(SecCollect, "Scan every", "CollectDelay", 1, 30, 3, "s")
H.slider(SecCollect, "Per-pack cooldown", "CollectPerPrompt", 0, 30, 5, "s")
H.toggle(SecCollect, "Walk to pack if far", "WalkNear", true, nil,
	"เซิร์ฟเวอร์มักเช็กระยะ จึงวาร์ปไปใกล้แพ็กก่อนกด")
H.toggle(SecCollect, "Return to spot after", "ReturnBack", true)
H.loop("AutoCollect", function() return H.State.CollectDelay end, collectAll)

SecCollect:Button():Add("Collect Now", function()
	task.spawn(function()
		local ok, e = pcall(collectAll)
		if not ok then H.err("collect", e) end
	end)
end)

----------------------------------------------------------------------
-- 2) Auto Collect Card Cash (remote ไม่มีอาร์กิวเมนต์)
----------------------------------------------------------------------
H.toggle(SecCollect, "Auto Collect Card Cash", "AutoCash", false, nil,
	"ยิง CollectAllCardCash (ไม่ใส่ค่า) ตามช่วงเวลา")
H.slider(SecCollect, "Cash every", "CashDelay", 2, 120, 8, "s")
H.loop("AutoCash", function() return H.State.CashDelay end, function()
	if H.fire("CollectAllCardCash") then H.Stats.Cash = H.Stats.Cash + 1 end
end)

SecCollect:Button():Add("Free Auto-Collect", function()
	H.fire("ActivateFreeAutoCollectRemote")
	H.notify("Auto", "ส่งคำขอเปิด Free Auto-Collect แล้ว", 3)
end)

----------------------------------------------------------------------
-- 3) Auto Reroll Packs (ProximityPrompt "Reroll Packs") — เสียเงินในเกม
----------------------------------------------------------------------
H.toggle(SecCollect, "Auto Reroll Packs (costs cash)", "AutoReroll", false, nil,
	"กด prompt Reroll Packs ในแปลง ใช้เงินในเกม ระวังเงินหมด")
H.slider(SecCollect, "Reroll every", "RerollDelay", 3, 120, 15, "s")
H.loop("AutoReroll", function() return H.State.RerollDelay end, function()
	local plot = H.myPlot()
	if not plot then return end
	for _, d in ipairs(plot:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Enabled and d.ActionText == "Reroll Packs" then
			local pos, hrp = H.promptPos(d), H.hrp()
			if pos and hrp then
				local home
				if (hrp.Position - pos).Magnitude > (d.MaxActivationDistance or 10) - 1.5 then
					home = hrp.CFrame
					hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3.2, 0))
					task.wait(0.15)
				end
				H.press(d)
				if home then task.wait(0.1) hrp.CFrame = home end
			end
			break
		end
	end
end)

----------------------------------------------------------------------
-- 4) รางวัลรายวัน/กลับมาเล่น (remote ไม่มีค่า)
----------------------------------------------------------------------
H.toggle(SecReward, "Auto Daily / Welcome-Back", "AutoDaily", false, nil,
	"ยิง ClaimDailyReward และ ClaimWelcomeBackReward ทุก 60 วินาที")
H.loop("AutoDaily", function() return 60 end, function()
	H.fire("ClaimDailyReward")
	H.fire("ClaimWelcomeBackReward")
	H.Stats.Claims = H.Stats.Claims + 1
end)

SecReward:Button():Add("Claim Now", function()
	H.fire("ClaimDailyReward")
	H.fire("ClaimWelcomeBackReward")
	H.notify("Auto", "ส่งคำขอรับรางวัลแล้ว", 3)
end)

----------------------------------------------------------------------
-- 5) GUI Clicker: กดปุ่มในเกมให้เอง (Claim / Skip / OK ...)
----------------------------------------------------------------------
local BUTTON_ITEMS = {
	"ClaimButton", "Claim", "SkipAll", "SkipButton", "AwesomeButton", "OkButton", "JoinButton", "StartButton",
}
H.State.GuiNames = { "ClaimButton", "Claim", "SkipAll", "SkipButton", "AwesomeButton", "OkButton" }

local BLOCKED_GUI = { ShopGui = true, PackRotationShopGui = true, ConfirmGui = true, UseTokenGui = true }

local cache, cacheT = {}, 0
local function refreshCache()
	cache = {}
	local want = {}
	local sel = H.State.GuiNames
	if type(sel) == "table" then
		for _, n in pairs(sel) do want[tostring(n)] = true end
	end
	for _, d in ipairs(PlayerGui:GetDescendants()) do
		if d:IsA("GuiButton") and want[d.Name] then
			local sg = d:FindFirstAncestorOfClass("ScreenGui")
			if not (sg and BLOCKED_GUI[sg.Name]) then cache[#cache + 1] = d end
		end
	end
	cacheT = os.clock()
end

H.toggle(SecReward, "Auto GUI Clicker", "AutoGui", false, function() cacheT = 0 end,
	"กดปุ่มที่เลือกเมื่อมันขึ้นบนจอ (เช่น Claim, Skip)")
H.slider(SecReward, "Check every", "GuiDelay", 0.5, 10, 2, "s")
H.dropdown(SecReward, "Buttons to click", "GuiNames", BUTTON_ITEMS,
	{ "ClaimButton", "Claim", "SkipAll", "SkipButton", "AwesomeButton", "OkButton" }, true,
	function() cacheT = 0 end)

H.loop("AutoGui", function() return H.State.GuiDelay end, function()
	if os.clock() - cacheT > 8 then refreshCache() end
	for _, b in ipairs(cache) do
		if b.Parent and H.shown(b) then
			H.clickGui(b)
			H.Stats.Claims = H.Stats.Claims + 1
			task.wait(0.15)
		end
	end
end)

SecReward:Button():Add("Rescan GUI", function()
	refreshCache()
	H.notify("GUI Clicker", "พบปุ่มที่ตรงชื่อ " .. #cache .. " ปุ่ม", 3)
end)

SecReward:Label({
	Name = "Tip",
	Description = "ถ้า remote ไม่ตอบสนอง ให้เปิดหน้าต่างรางวัลในเกม แล้วใช้ GUI Clicker กดแทน",
})
