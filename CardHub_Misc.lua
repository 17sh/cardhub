-- CardHub_Misc.lua : เซิร์ฟเวอร์ / Auto Rejoin / โค้ด / ตัวยิง remote / ปิดสคริป
local H = ...
local Window = H.Window
local Players = H.Players
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local Page = Window:CreatePage({ Name = "Misc" })
local SecServer = Page:CreateSection({ Name = "Server", Side = 1, Collapsed = false })
local SecTools  = Page:CreateSection({ Name = "Tools", Side = 2, Collapsed = false })

----------------------------------------------------------------------
-- Server
----------------------------------------------------------------------
local function rejoin()
	H.notify("Server", "กำลัง Rejoin...", 3)
	if #Players:GetPlayers() <= 1 then
		pcall(function() H.lp:Kick("\nRejoining...") end)
		task.wait(0.5)
		TeleportService:Teleport(game.PlaceId, H.lp)
	else
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, H.lp)
	end
end

local function httpGet(url)
	if type(game.HttpGet) == "function" then
		local ok, body = pcall(function() return game:HttpGet(url) end)
		if ok then return body end
	end
	local req = (syn and syn.request) or request or http_request or (http and http.request)
	if req then
		local ok, res = pcall(req, { Url = url, Method = "GET" })
		if ok and res and res.Body then return res.Body end
	end
	return nil
end

local function hop(mode) -- "small" | "any"
	H.notify("Server Hop", "กำลังหาเซิร์ฟเวอร์...", 3)
	task.spawn(function()
		local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
			.. "/servers/Public?sortOrder=" .. (mode == "small" and "Asc" or "Desc") .. "&limit=100"
		local body = httpGet(url)
		local ok, data = pcall(function() return HttpService:JSONDecode(body or "") end)
		if not (ok and data and data.data) then
			H.notify("Server Hop", "ดึงรายชื่อเซิร์ฟเวอร์ไม่ได้", 4)
			return
		end
		local best
		for _, s in ipairs(data.data) do
			if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
				if not best or (mode == "small" and s.playing < best.playing) then
					best = s
					if mode ~= "small" then break end
				end
			end
		end
		if best then
			TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, H.lp)
		else
			H.notify("Server Hop", "ไม่พบเซิร์ฟเวอร์ที่เหมาะสม", 4)
		end
	end)
end

SecServer:Button():Add("Rejoin", rejoin):Add("Hop (small)", function() hop("small") end)
SecServer:Button():Add("Hop (any)", function() hop("any") end)
	:Add("Copy JobId", function()
		if setclipboard then setclipboard(game.JobId) H.notify("Server", "คัดลอก JobId แล้ว", 2) end
	end)

----------------------------------------------------------------------
-- Auto Rejoin เมื่อหลุด/ถูกเตะ
----------------------------------------------------------------------
H.toggle(SecServer, "Auto Rejoin on disconnect", "AutoRejoin", true, nil,
	"เมื่อขึ้นหน้าจอ error จะ Rejoin อัตโนมัติ (ใช้คู่กับ Auto Execute ใน Settings)")

local rejoining = false
pcall(function()
	local cg = game:GetService("CoreGui")
	local overlay = cg:WaitForChild("RobloxPromptGui", 10)
	overlay = overlay and overlay:WaitForChild("promptOverlay", 10)
	if overlay then
		H.conn(overlay.ChildAdded, function(c)
			if c.Name == "ErrorPrompt" and H.State.AutoRejoin and not rejoining then
				rejoining = true
				task.wait(2)
				pcall(function() TeleportService:Teleport(game.PlaceId, H.lp) end)
			end
		end)
	end
end)

----------------------------------------------------------------------
-- Redeem Code
----------------------------------------------------------------------
local codeText = ""
SecTools:Textbox({
	Name = "Code", Flag = "CodeBox", Placeholder = "ใส่โค้ดจากผู้พัฒนา", Finished = true,
	Callback = function(t) codeText = t or "" end,
})
SecTools:Button({ Name = "Redeem Code", Callback = function()
	local c = codeText:gsub("^%s+", ""):gsub("%s+$", "")
	if c == "" then H.notify("Redeem", "ใส่โค้ดก่อน", 2) return end
	H.fire("RedeemCode", c)
	H.notify("Redeem", "ส่งโค้ด " .. c .. " แล้ว", 3)
end })

----------------------------------------------------------------------
-- Remote Launcher (ยิงแบบไม่มีค่า เฉพาะ remote ที่ไม่เกี่ยวกับเงิน/เทรด)
----------------------------------------------------------------------
local BLOCK = {
	"Purchase", "Buy", "Robux", "Gift", "Trade", "Delete", "Sell", "Salvage", "Fuse", "Burn",
	"Leave", "Reroll", "Craft", "Integrity", "Chat", "Block", "Party", "Clan", "Auction", "Pvp", "PvP",
}
local function allowed(name)
	for _, b in ipairs(BLOCK) do
		if name:find(b, 1, true) then return false end
	end
	return true
end

local function remoteList()
	local t = {}
	local f = H.remotes()
	if f then
		for _, r in ipairs(f:GetChildren()) do
			if (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) and allowed(r.Name) then
				t[#t + 1] = r.Name
			end
		end
	end
	table.sort(t)
	if #t == 0 then t[1] = "(none)" end
	return t
end

local rd = H.dropdown(SecTools, "Remote", "RemotePick", remoteList(), nil, false)
SecTools:Button():Add("Fire (no args)", function()
	local n = H.State.RemotePick
	if not n or n == "(none)" then return end
	if H.fire(n) then H.notify("Remote", "ยิง " .. n .. " แล้ว", 2) end
end):Add("Refresh", function()
	pcall(function() rd:Refresh(remoteList()) end)
end)

SecTools:Label({
	Name = "Safe list",
	Description = "รายการนี้ตัด remote ที่เกี่ยวกับซื้อ/ขาย/เทรด/ลบ/คราฟต์/ต่อสู้ออกให้แล้ว",
})

----------------------------------------------------------------------
-- Utilities
----------------------------------------------------------------------
SecTools:Button():Add("Copy PlaceId", function()
	if setclipboard then setclipboard(tostring(game.PlaceId)) H.notify("Misc", "คัดลอก PlaceId แล้ว", 2) end
end):Add("Dump Plot Info", function()
	local plot = H.myPlot()
	if not plot then H.notify("Misc", "ไม่พบแปลงของคุณ", 3) return end
	local packs = 0
	for _, d in ipairs(plot:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.ActionText == "Collect" then packs = packs + 1 end
	end
	H.notify("Plot", plot.Name .. " | แพ็กที่เก็บได้: " .. packs, 5)
end)

SecTools:Button({ Name = "Unload Script (stop everything)", Callback = function()
	H.Library:ConfirmDialog({
		Message = "ปิดสคริปทั้งหมดและลบเมนู?",
		OnConfirm = function() H.Stop() end,
	})
end })
