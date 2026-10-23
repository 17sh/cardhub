-- CardHub_Teleport.lua : เทเลพอร์ต (พิกัดจากไฟล์ dump ของแมพ)
local H = ...
local Window = H.Window
local Players = H.Players

local Page = Window:CreatePage({ Name = "Teleport" })
local SecPlaces = Page:CreateSection({ Name = "Places", Side = 1, Collapsed = false })
local SecPlayers = Page:CreateSection({ Name = "Players & Spots", Side = 2, Collapsed = false })

-- พิกัดอ่านจากไฟล์ MapDump (Workspace.Systems.Teleports ฯลฯ)
local PLACES = {
	["Hub Spawn"]         = Vector3.new(38, 17, 46),
	["Pack Shop"]         = Vector3.new(36, 22, 51),
	["Market"]            = Vector3.new(192, 19, 55),
	["Clans"]             = Vector3.new(36, 22, 233),
	["Clan Shop"]         = Vector3.new(-31, 22, 233),
	["Leaderboards"]      = Vector3.new(36, 21, -228),
	["Obby Entrance"]     = Vector3.new(-70, 19, 54),
	["Money Pit"]         = Vector3.new(460, 10, 44),
	["World Boss Board"]  = Vector3.new(79, 26, -18),
	["Player Shop A"]     = Vector3.new(231, 17, 31),
	["Player Shop B"]     = Vector3.new(279, 17, 78),
	["Player Shop C"]     = Vector3.new(211, 17, 78),
	["Player Shop D"]     = Vector3.new(245, 17, 78),
}
local names = { "My Plot" }
do
	local tmp = {}
	for k in pairs(PLACES) do tmp[#tmp + 1] = k end
	table.sort(tmp)
	for _, k in ipairs(tmp) do names[#names + 1] = k end
end

H.State.TpPlace = "My Plot"
H.State.TpTween = false
H.State.TpSpeed = 120

local function gotoPos(target, label)
	if not target then
		H.notify("Teleport", "ไม่พบตำแหน่ง: " .. tostring(label), 3)
		return
	end
	if not H.hrp() then return end
	local r = H.tp(target, H.State.TpTween, H.State.TpSpeed)
	if r then H.notify("Teleport", "ไปที่ " .. tostring(label), 2) end
end

H.dropdown(SecPlaces, "Destination", "TpPlace", names, "My Plot", false)
H.toggle(SecPlaces, "Smooth (tween)", "TpTween", false, nil, "เคลื่อนไปแบบต่อเนื่อง ลดโอกาสโดนตรวจจับ")
H.slider(SecPlaces, "Tween speed", "TpSpeed", 40, 300, 120, " st/s")

SecPlaces:Button():Add("Teleport", function()
	local p = H.State.TpPlace
	if p == "My Plot" then
		gotoPos(H.plotSpawn(), "My Plot")
	else
		gotoPos(PLACES[p], p)
	end
end):Add("To My Plot", function()
	gotoPos(H.plotSpawn(), "My Plot")
end)

-- ปุ่มลัดรายตำแหน่ง
for _, key in ipairs({ "Hub Spawn", "Pack Shop", "Market", "Money Pit" }) do
	SecPlaces:Button({ Name = "Go: " .. key, Callback = function() gotoPos(PLACES[key], key) end })
end

----------------------------------------------------------------------
-- ผู้เล่น
----------------------------------------------------------------------
local function playerNames()
	local t = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= H.lp then t[#t + 1] = p.Name end
	end
	table.sort(t)
	if #t == 0 then t[1] = "(none)" end
	return t
end

local pd = H.dropdown(SecPlayers, "Player", "TpPlayer", playerNames(), nil, false)

local function refreshPlayers()
	pcall(function() pd:Refresh(playerNames()) end)
end
H.conn(Players.PlayerAdded, refreshPlayers)
H.conn(Players.PlayerRemoving, function() task.delay(0.2, refreshPlayers) end)

SecPlayers:Button():Add("Refresh", refreshPlayers):Add("To Player", function()
	local n = H.State.TpPlayer
	local pl = n and Players:FindFirstChild(n)
	local hrp = pl and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
	gotoPos(hrp and (hrp.CFrame * CFrame.new(0, 0, 4)), n)
end)

SecPlayers:Button({ Name = "To Player's Plot", Callback = function()
	local n = H.State.TpPlayer
	gotoPos(n and H.plotSpawn(H.plotOf(n)), (n or "?") .. " plot")
end })

----------------------------------------------------------------------
-- จุดที่บันทึกเอง
----------------------------------------------------------------------
local saved
SecPlayers:Button():Add("Save Spot", function()
	local hrp = H.hrp()
	if hrp then
		saved = hrp.CFrame
		H.notify("Teleport", "บันทึกตำแหน่งปัจจุบันแล้ว", 2)
	end
end):Add("Back to Spot", function()
	if saved then gotoPos(saved, "Saved Spot") else H.notify("Teleport", "ยังไม่ได้บันทึกตำแหน่ง", 2) end
end)

SecPlayers:Label({
	Name = "Note",
	Description = "เกมอาจเช็กระยะวาร์ป ถ้าถูกดึงกลับให้เปิด Smooth (tween)",
})
