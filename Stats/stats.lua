local _, addon = ...
local core = addon.core

local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local UIParent = UIParent
local FocusDataPanel = FocusDataPanel
local GetNumAddOns = GetNumAddOns
local UpdateAddOnMemoryUsage = UpdateAddOnMemoryUsage
local GetAddOnMemoryUsage = GetAddOnMemoryUsage
local GetAddOnInfo = GetAddOnInfo
local IsAddOnLoaded = IsAddOnLoaded
local GetNetStats = GetNetStats
local GetFramerate = GetFramerate
local GetMoney = GetMoney
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax
local UnitLevel = UnitLevel
local GetXPExhaustion = GetXPExhaustion
local C_Reputation = C_Reputation

-- memory ---------------

local format_mem = function(mem)
	local value = mem / 8192
	local new_mem = mem > 1024 and mem / 1024 or mem
	local size = mem > 1024 and "mb" or "kb"
	if value > 1 then
		value = 1
	end
	return string.format("%.1f|c%s %s|r", new_mem, core.player.color_str, size)
end

local mem_text = core.util.gen_string(FocusDataPanel)
FocusDataPanel:add_left(mem_text)

local mem_button = CreateFrame("Button", "FocusStatsMem", UIParent)
mem_button:SetAllPoints(mem_text)
mem_button.text = mem_text
mem_button.last = 0

mem_button:RegisterEvent("PLAYER_LOGIN")
mem_button:SetScript("OnEvent", function(self)
	self.num = GetNumAddOns()
	local mem_sum = 0
	UpdateAddOnMemoryUsage()
	for i = 1, self.num do
		mem_sum = mem_sum + GetAddOnMemoryUsage(i)
	end
	self.text:SetText(format_mem(mem_sum))
end)

local mem_update = function(button)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Memory", 1, 1, 1)
	GameTooltip:AddLine(" ")
	local mem_sum = 0
	local mem_list = {}
	UpdateAddOnMemoryUsage()
	for i = 1, button.num do
		local _, name = GetAddOnInfo(i)
		local memory = 0
		if IsAddOnLoaded(i) then
			memory = GetAddOnMemoryUsage(i)
			table.insert(mem_list, {
				name = name,
				memory = memory
			})
		end
		mem_sum = mem_sum + memory
	end
	table.sort(mem_list, function(a, b)
		return a.memory > b.memory
	end)
	for _, entry in pairs(mem_list) do
		GameTooltip:AddDoubleLine(entry.name..":", format_mem(entry.memory), 1, 1, 1, 1, 1, 1)
	end
	local total_mem = collectgarbage("count")
	local blizz_mem = total_mem - mem_sum
	GameTooltip:AddLine(" ")
	GameTooltip:AddDoubleLine("AddOn Memory:", format_mem(mem_sum), 1, 1, 1, 1, 1, 1)
	GameTooltip:AddDoubleLine("Default UI Memory:", format_mem(blizz_mem), 1, 1, 1, 1, 1, 1)
	GameTooltip:AddDoubleLine("Total Memory:", format_mem(total_mem), 1, 1, 1, 1, 1, 1)
	GameTooltip:Show()
	button.text:SetText(format_mem(mem_sum))
end

mem_button:SetScript("OnEnter", mem_update)
mem_button:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)
mem_button:SetScript("OnUpdate", function(self, last)
	if self.num then
		self.last = self.last + last
		if self.last >= 2 then
			local mem_sum = 0
			UpdateAddOnMemoryUsage()
			for i = 1, self.num do
				mem_sum = mem_sum + GetAddOnMemoryUsage(i)
			end
			mem_text:SetText(format_mem(mem_sum))
			self.last = 0
		end
	end
end)
mem_button:SetScript("OnClick", function(self, button)
	if button == "LeftButton" then
		UpdateAddOnMemoryUsage()
		local old_mem = collectgarbage("count")
		collectgarbage()
		UpdateAddOnMemoryUsage()
		print("Garbage collected: ", format_mem(old_mem - collectgarbage("count")))
		self.last = 2
		mem_update(self)
	end
end)

-- latency --------------

local net_text = core.util.gen_string(FocusDataPanel)
FocusDataPanel:add_left(net_text)

local net_button = CreateFrame("Frame", "FocusStatsNet", UIParent)
net_button:SetAllPoints(net_text)
net_button.text = net_text
net_button.last = 0

net_button:RegisterEvent("PLAYER_LOGIN")
net_button:SetScript("OnEvent", function(self)
	local _, _, home, world = GetNetStats()
	self.text:SetText(string.format("%s|c%sh|r %s|c%sw|r", home, core.player.color_str, world, core.player.color_str))
end)
net_button:SetScript("OnUpdate", function(self, last)
	self.last = self.last + last
	if self.last >= 2 then
		local _, _, home, world = GetNetStats()
		self.text:SetText(string.format("%s|c%sh|r %s|c%sw|r", home, core.player.color_str, world, core.player.color_str))
		self.last = 0
	end
end)

-- framerate ------------

local fps_text = core.util.gen_string(FocusDataPanel)
FocusDataPanel:add_left(fps_text)

local fps_frame = CreateFrame("Frame", "FocusStatsFps", UIParent)
fps_frame:SetAllPoints(fps_text)
fps_frame.text = fps_text
fps_frame.last = 0

fps_frame:RegisterEvent("PLAYER_LOGIN")
fps_frame:SetScript("OnEvent", function(self)
	local fps = GetFramerate()
	self.text:SetText(string.format("%d|c%sfps|r", math.floor(fps), core.player.color_str, "fps"))
end)
fps_frame:SetScript("OnUpdate", function(self, last)
	self.last = self.last + last
	if self.last >= 0.25 then
		self.last = 0
		local fps = GetFramerate()
		self.text:SetText(string.format("%d|c%sfps|r", math.floor(fps), core.player.color_str, "fps"))
	end
end)

-- gold -------------

local format_gold = function(rawgold)
	return string.format("%d|c%sg|r", math.floor(rawgold * 0.0001), core.player.color_str)
end

local gold_text = core.util.gen_string(FocusDataPanel)
FocusDataPanel:add_right(gold_text)

local gold_frame = CreateFrame("Button", "FocusStatsGold", UIParent)
gold_frame:SetAllPoints(gold_text)
gold_frame.text = gold_text

gold_frame:RegisterEvent("ADDON_LOADED")
gold_frame:RegisterEvent("PLAYER_LOGIN")
gold_frame:RegisterEvent("PLAYER_MONEY")
gold_frame:SetScript("OnEvent", function(self, event)
	if event == "ADDON_LOADED" and addon == "Focus" then
		if not FocusStatsRealmGold then FocusStatsRealmGold = {} end
		if not FocusStatsRealmGold[core.player.realm] then FocusStatsRealmGold[core.player.realm] = {} end
	end
	if FocusStatsRealmGold then
		local new_gold = GetMoney()
		self.text:SetText(format_gold(new_gold))
		FocusStatsRealmGold[core.player.realm][core.player.name] = new_gold
	end
end)
gold_frame:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(string.format("Gold on |c%s%s|r", core.player.color_str, core.player.realm), 1, 1, 1)
	GameTooltip:AddLine(" ")
	local sum = 0
	for player, gold in pairs(FocusStatsRealmGold[core.player.realm]) do
		GameTooltip:AddDoubleLine(player, format_gold(gold), 1, 1, 1, 1, 1, 1)
		sum = sum + gold
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddDoubleLine("Total:", format_gold(sum), 1, 1, 1, 1, 1, 1)
	GameTooltip:Show()
end)
gold_frame:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

-- level -----------------

local level_text = core.util.gen_string(FocusDataPanel)
FocusDataPanel:add_right(level_text)

local level_frame = CreateFrame("Frame", "FocusStatsAzerite", UIParent)
level_frame:SetAllPoints(level_text)
level_frame.text = level_text

level_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
level_frame:RegisterEvent("PLAYER_LEVEL_UP")
level_frame:RegisterEvent("PLAYER_XP_UPDATE")
level_frame:RegisterEvent("UPDATE_EXHAUSTION")
level_frame:RegisterEvent("UPDATE_EXPANSION_LEVEL")
level_frame:RegisterEvent("PLAYER_UPDATE_RESTING")
level_frame:SetScript("OnEvent", function(self)
	local cur_xp = UnitXP("player")
	local max_xp = UnitXPMax("player")
	local level = UnitLevel("player")
	local level_perc = math.floor(cur_xp / max_xp * 100 + 0.5)

	self.text:SetText(string.format("%s - %d|c%s%s|r", level, level_perc, core.player.color_str, "%"))
end)
level_frame:SetScript("OnEnter", function(self)
	local cur_xp = UnitXP("player")
	local max_xp = UnitXPMax("player")
	local level = UnitLevel("player")
	local rested = GetXPExhaustion() or 0

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(string.format("Level |c%s%d|r", core.player.color_str, level), 1, 1, 1)
	GameTooltip:AddLine(string.format("%d / %d", cur_xp, max_xp), 1, 1, 1)
	GameTooltip:AddLine(string.format("|c%s%d|r rested", core.player.color_str, rested), 1, 1, 1)

	-- reputations
	local reps = {
		[2164] = "Champions",
		[2157] = "Honorbound",
		[2391] = "Rustbolt",
		[2163] = "Tortollan",
		[2373] = "Unshackled",
		[2158] = "Voldunai",
		[2103] = "Zandalari",
		[2156] = "Talanji's",
	}

	local has_rep = false
	for id, name in pairs(reps) do
		if (C_Reputation.IsFactionParagon(id)) then
			if not has_rep then
				GameTooltip:AddLine(" ")
				has_rep = true
			end
			local cur_rep, max_rep, _, has_reward = C_Reputation.GetFactionParagonInfo(id);
			local value = cur_rep % max_rep;
			if has_reward then
				value = value + max_rep;
			end
			GameTooltip:AddDoubleLine(name, string.format("|c%s%d / %d|r", core.player.color_str, value, max_rep), 1, 1, 1, 1, 1, 1)
		end
	end

	GameTooltip:Show()
end)
level_frame:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)
