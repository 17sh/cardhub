--[[
	CardHub.lua  (ไฟล์หลัก)
	รันจาก GitHub (บรรทัดเดียว) โดยแก้ USERNAME/REPO ให้เป็นของคุณ:
	getgenv().CardHubBase="https://raw.githubusercontent.com/USERNAME/REPO/main/";loadstring(game:HttpGet(getgenv().CardHubBase.."CardHub.lua"))()

	รันจากไฟล์ในเครื่อง (ถ้าไม่ตั้ง CardHubBase):
	loadstring(readfile("CardHub.lua"))()

	ไฟล์ที่ต้องมีใน repo (หรือใน Workspace):
	  UILIB.lua  CardHub.lua
	  CardHub_Auto.lua  CardHub_Click.lua  CardHub_Player.lua
	  CardHub_Teleport.lua  CardHub_Visual.lua  CardHub_Misc.lua
]]

-- ปิดของเก่าถ้ารันซ้ำ
if getgenv().CardHub and getgenv().CardHub.Stop then
	pcall(getgenv().CardHub.Stop)
end

----------------------------------------------------------------------
-- Services
----------------------------------------------------------------------
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

-- ดึงไฟล์: ถ้ามี CardHubBase ให้โหลดจาก GitHub ก่อน ไม่สำเร็จค่อยใช้ไฟล์ในเครื่อง
local BASE = getgenv().CardHubBase
local function fetch(name)
	if type(BASE) == "string" and BASE ~= "" then
		local ok, body = pcall(function() return game:HttpGet(BASE .. name) end)
		if ok and type(body) == "string" and #body > 20 and body:sub(1, 3) ~= "404" then
			return body
		end
	end
	if isfile and isfile(name) then return readfile(name) end
	return nil
end

local uiSrc = fetch("UILIB.lua")
if not uiSrc then
	warn("[CardHub] โหลด UILIB.lua ไม่ได้ (เช็กลิงก์ GitHub หรือไฟล์ในเครื่อง)")
	return
end
local uiFn, uiErr = loadstring(uiSrc, "=UILIB.lua")
if not uiFn then warn("[CardHub] UILIB.lua syntax error: " .. tostring(uiErr)) return end
local Library = uiFn()

-- ไม่ดึงโลโก้จากเว็บนอก
Library.LogoUrl = ""
Library.LogoFallback = ""
if type(BASE) == "string" and BASE ~= "" then
	Library.AutoExecuteScript = 'getgenv().CardHubBase="' .. BASE .. '";loadstring(game:HttpGet("' .. BASE .. 'CardHub.lua"))()'
else
	Library.AutoExecuteScript = 'loadstring(readfile("CardHub.lua"))()'
end

----------------------------------------------------------------------
-- ตัวกลางที่ทุกโมดูลใช้ร่วมกัน (H)
----------------------------------------------------------------------
local H = {
	Alive = true,
	State = {},       -- ค่าสวิตช์/สไลเดอร์ทั้งหมด (อ่านง่ายจากทุกไฟล์)
	Stats = { Collected = 0, Cash = 0, Clicks = 0, Claims = 0, Errors = 0, Start = os.clock() },
	Conns = {},
	Cleanups = {},
	Library = Library,
	IsMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled,
	LastError = "-",
}
getgenv().CardHub = H

H.lp = Players.LocalPlayer
H.Players, H.RS, H.RunService, H.UIS, H.GuiService, H.Workspace =
	Players, RS, RunService, UIS, GuiService, Workspace

function H.char() return H.lp.Character end
function H.hum()
	local c = H.lp.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
function H.hrp()
	local c = H.lp.Character
	return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

function H.notify(title, desc, dur)
	pcall(function()
		Library:Notification({ Title = title or "Card Hub", Description = desc or "", Duration = dur or 3 })
	end)
end

function H.err(where, e)
	H.Stats.Errors = H.Stats.Errors + 1
	H.LastError = tostring(where) .. ": " .. tostring(e):sub(1, 60)
end

function H.conn(signal, fn)
	local c = signal:Connect(fn)
	H.Conns[#H.Conns + 1] = c
	return c
end

function H.onStop(fn) H.Cleanups[#H.Cleanups + 1] = fn end

-- วนทำงานเมื่อสวิตช์ key เปิดอยู่ (delay เป็นฟังก์ชันคืนค่าวินาที)
function H.loop(key, delay, fn)
	task.spawn(function()
		while H.Alive do
			if H.State[key] then
				local ok, e = pcall(fn)
				if not ok then H.err(key, e) end
				task.wait(math.max(0.05, delay and delay() or 1))
			else
				task.wait(0.3)
			end
		end
	end)
end

-- สร้าง Toggle ที่เก็บค่าลง H.State[key] ให้อัตโนมัติ
function H.toggle(section, name, key, default, cb, tip)
	H.State[key] = default and true or false
	return section:Toggle({
		Name = name, Flag = key, Default = default and true or false, Tooltip = tip,
		Callback = function(v)
			H.State[key] = v
			if cb then
				local ok, e = pcall(cb, v)
				if not ok then H.err(key, e) end
			end
		end,
	})
end

function H.slider(section, name, key, min, max, default, suffix, cb)
	H.State[key] = default
	return section:Slider({
		Name = name, Flag = key, Min = min, Max = max, Default = default,
		Suffix = suffix or "", Compact = false,
		Callback = function(v)
			H.State[key] = v
			if cb then
				local ok, e = pcall(cb, v)
				if not ok then H.err(key, e) end
			end
		end,
	})
end

function H.dropdown(section, name, key, items, default, multi, cb)
	H.State[key] = default
	return section:Dropdown({
		Name = name, Flag = key, Items = items, Default = default, Multi = multi or false,
		Callback = function(v)
			H.State[key] = v
			if cb then
				local ok, e = pcall(cb, v)
				if not ok then H.err(key, e) end
			end
		end,
	})
end

----------------------------------------------------------------------
-- Remote / Plot / Prompt / GUI helpers
----------------------------------------------------------------------
function H.remotes()
	return RS:FindFirstChild("Remotes")
end

-- ยิง remote แบบไม่ค้าง (รองรับทั้ง RemoteEvent / RemoteFunction)
function H.fire(name, ...)
	local folder = H.remotes()
	local r = folder and folder:FindFirstChild(name)
	if not r then return false, "no remote: " .. name end
	local args = table.pack(...)
	task.spawn(function()
		local ok, e
		if r:IsA("RemoteFunction") then
			ok, e = pcall(r.InvokeServer, r, table.unpack(args, 1, args.n))
		else
			ok, e = pcall(r.FireServer, r, table.unpack(args, 1, args.n))
		end
		if not ok then H.err(name, e) end
	end)
	return true
end

-- แปลงของที่ผู้เล่นเป็นเจ้าของ: Workspace.Map.PlotModels[ชื่อผู้เล่น]
function H.myPlot()
	local map = Workspace:FindFirstChild("Map")
	local pm = map and map:FindFirstChild("PlotModels")
	if not pm then return nil end
	return pm:FindFirstChild(H.lp.Name) or pm:FindFirstChild(H.lp.DisplayName)
end

function H.plotOf(playerName)
	local map = Workspace:FindFirstChild("Map")
	local pm = map and map:FindFirstChild("PlotModels")
	return pm and pm:FindFirstChild(playerName)
end

function H.plotSpawn(plot)
	plot = plot or H.myPlot()
	if not plot then return nil end
	local sp = plot:FindFirstChild("SpawnPart", true) or plot:FindFirstChild("Base", true)
	return sp and sp.Position
end

-- กดปุ่ม ProximityPrompt
function H.press(prompt)
	if fireproximityprompt then
		pcall(fireproximityprompt, prompt)
	else
		pcall(function()
			prompt:InputHoldBegin()
			task.wait((prompt.HoldDuration or 0) + 0.08)
			prompt:InputHoldEnd()
		end)
	end
end

function H.promptPos(p)
	local par = p.Parent
	if par and par:IsA("BasePart") then return par.Position end
	if par and par:IsA("Attachment") then return par.WorldPosition end
	if par and par:IsA("Model") then
		local ok, cf = pcall(par.GetPivot, par)
		if ok then return cf.Position end
	end
	return nil
end

-- ปุ่ม GUI มองเห็นอยู่จริงไหม
function H.shown(o)
	local pg = H.lp:FindFirstChild("PlayerGui")
	while o and o ~= pg and o.Parent do
		if o:IsA("GuiObject") and not o.Visible then return false end
		if o:IsA("ScreenGui") and not o.Enabled then return false end
		o = o.Parent
	end
	return true
end

-- แตะที่พิกัดหน้าจอ (viewport) ด้วย VirtualInputManager
local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)
H.VIM = VIM

function H.tapAt(x, y, mode)
	if not VIM then return false end
	mode = mode or (H.IsMobile and "Touch" or "Mouse")
	pcall(function()
		if mode == "Touch" then
			VIM:SendTouchEvent(1, 0, x, y)
			task.wait(0.02)
			VIM:SendTouchEvent(1, 2, x, y)
		else
			VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
			task.wait(0.02)
			VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
		end
	end)
	return true
end

-- คลิกปุ่ม GUI: ใช้ firesignal ก่อน ถ้าไม่มีให้แตะจริงที่กลางปุ่ม
function H.clickGui(b)
	if firesignal then
		pcall(firesignal, b.MouseButton1Click)
		pcall(firesignal, b.Activated)
		return true
	end
	if getconnections then
		local n = 0
		for _, sig in ipairs({ b.MouseButton1Click, b.Activated }) do
			local ok, cons = pcall(getconnections, sig)
			if ok and cons then
				for _, c in ipairs(cons) do
					if c.Function then pcall(c.Function) n = n + 1 end
				end
			end
		end
		if n > 0 then return true end
	end
	local inset = GuiService:GetGuiInset()
	local p, s = b.AbsolutePosition, b.AbsoluteSize
	return H.tapAt(p.X + s.X / 2, p.Y + s.Y / 2 + inset.Y)
end

-- เทเลพอร์ต (CFrame/Vector3)
function H.tp(target, tween, speed)
	local hrp = H.hrp()
	if not hrp then return false end
	local cf = typeof(target) == "Vector3" and CFrame.new(target + Vector3.new(0, 4, 0)) or target
	if tween then
		local dist = (hrp.Position - cf.Position).Magnitude
		local t = math.clamp(dist / math.max(10, speed or 120), 0.1, 12)
		local tw = game:GetService("TweenService"):Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = cf })
		tw:Play()
		return tw
	end
	hrp.CFrame = cf
	return true
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
local Window = Library:Window({ Name = "Card Hub | Pack Tycoon", Game = "Card Pack Game" })
H.Window = Window

----------------------------------------------------------------------
-- หน้า Info (สถิติ)
----------------------------------------------------------------------
local InfoPage = Window:CreatePage({ Name = "Info" })
local StatSec = InfoPage:CreateSection({ Name = "Session", Side = 1, Collapsed = false })
local HelpSec = InfoPage:CreateSection({ Name = "How to use", Side = 2, Collapsed = false })

local L_time = StatSec:Label("Time: 0:00")
local L_col  = StatSec:Label("Packs collected: 0")
local L_cash = StatSec:Label("Cash collects: 0")
local L_clk  = StatSec:Label("Clicks: 0")
local L_clm  = StatSec:Label("Claims: 0")
local L_err  = StatSec:Label("Last error: -")

HelpSec:Label({
	Name = "Quick start",
	Description = "1) หน้า Auto: เปิด Auto Collect  2) หน้า Click: ตั้ง Auto Click  3) หน้า Misc: เปิด Auto Rejoin / 3D Off ถ้าจะทิ้งเครื่องไว้  ปุ่มลอยบนจอใช้เปิด/ปิดเมนู",
})
HelpSec:Label({
	Name = "Note",
	Description = "remote บางตัวไม่ทราบอาร์กิวเมนต์จริง ถ้ากดแล้วไม่เกิดผล แปลว่าเซิร์ฟเวอร์ไม่รับค่าว่าง ใช้ระบบ GUI Clicker แทน",
})

task.spawn(function()
	while H.Alive do
		local t = math.floor(os.clock() - H.Stats.Start)
		pcall(function()
			L_time:SetText(("Time: %d:%02d:%02d"):format(t // 3600, (t % 3600) // 60, t % 60))
			L_col:SetText("Packs collected: " .. H.Stats.Collected)
			L_cash:SetText("Cash collects: " .. H.Stats.Cash)
			L_clk:SetText("Clicks: " .. H.Stats.Clicks)
			L_clm:SetText("Claims: " .. H.Stats.Claims)
			L_err:SetText("Last error: " .. H.LastError)
		end)
		task.wait(1)
	end
end)

----------------------------------------------------------------------
-- โหลดโมดูลที่เหลือ (แต่ละไฟล์ที่พังจะไม่ทำให้ไฟล์อื่นพังตาม)
----------------------------------------------------------------------
local modules = {
	"CardHub_Auto.lua", "CardHub_Click.lua", "CardHub_Player.lua",
	"CardHub_Teleport.lua", "CardHub_Visual.lua", "CardHub_Misc.lua",
}
local failed = {}
for _, name in ipairs(modules) do
	local src = fetch(name)
	if src then
		local fn, perr = loadstring(src, "=" .. name)
		if fn then
			local ok, e = pcall(fn, H)
			if not ok then failed[#failed + 1] = name .. ": " .. tostring(e):sub(1, 80) end
		else
			failed[#failed + 1] = name .. " (syntax): " .. tostring(perr):sub(1, 80)
		end
	else
		failed[#failed + 1] = name .. " (not found)"
	end
end

----------------------------------------------------------------------
-- Settings (ธีม/คอนฟิก) + หยุดทั้งหมด
----------------------------------------------------------------------
local Watermark = Library:Watermark({ Name = "Card Hub", Options = { "fps", "ping", "time" } })
local KeyList = Library:KeybindList("Active Keybinds")
Library:CreateSettingsPage(Window, Watermark, KeyList)

function H.Stop()
	H.Alive = false
	for k in pairs(H.State) do H.State[k] = false end
	for _, c in ipairs(H.Conns) do pcall(function() c:Disconnect() end) end
	for _, fn in ipairs(H.Cleanups) do pcall(fn) end
	pcall(function() Library:Unload() end)
	if getgenv().CardHub == H then getgenv().CardHub = nil end
end

Window:SetOpen(true)

if #failed > 0 then
	H.notify("Card Hub", "โหลดไม่ครบ: " .. table.concat(failed, " | "), 8)
	H.LastError = failed[1]
else
	H.notify("Card Hub", "โหลดสำเร็จ " .. #modules .. " โมดูล", 4)
end
