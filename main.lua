--[[
	main.lua
		The bagnon driver thingy
--]]

local ADDON, Addon = ...
_G[ADDON] = Addon
Addon.frames = {}

local L = LibStub('AceLocale-3.0'):GetLocale(ADDON)
BINDING_HEADER_BAGNON = ADDON
BINDING_NAME_BAGNON_TOGGLE = L.ToggleBags
BINDING_NAME_BAGNON_BANK_TOGGLE = L.ToggleBank
BINDING_NAME_BAGNON_VAULT_TOGGLE = L.ToggleVault


--[[ Startup ]]--

function Addon:OnEnable()
	self:StartupSettings()
	self:AddSlashCommands()
	self:HookBagClickEvents()
	self:HookTooltips()

	self:CreateFrame('inventory')
	self:CreateFrameLoader(ADDON .. '_GuildBank', 'GuildBankFrame_LoadUI')
	self:CreateFrameLoader(ADDON .. '_VoidStorage', 'VoidStorage_LoadUI')
	self:CreateOptionsLoader()
	self:CreateLDBLauncher()
end

function Addon:CreateOptionsLoader()
	local f = CreateFrame('Frame', nil, InterfaceOptionsFrame)
	f:SetScript('OnShow', function(self)
		self:SetScript('OnShow', nil)
		LoadAddOn(ADDON .. '_Config')
	end)
end

function Addon:CreateFrameLoader (addon, method)
	if GetAddOnEnableState(UnitName('player'), addon) >= 2 then
		_G[method] = function()
			LoadAddOn(addon)
		end
	end
end

function Addon:CreateLDBLauncher()
	local LDB = LibStub:GetLibrary('LibDataBroker-1.1', true)
	if not LDB then return end

	LDB:NewDataObject(ADDON .. 'Launcher', {
		type = 'launcher',
		icon = [[Interface\Icons\INV_Misc_Bag_07]],
		text = ADDON,

		OnClick = function(_, button)
			if button == 'LeftButton' then
				if IsShiftKeyDown() then
					Addon:ToggleFrame('bank')
				else
					Addon:ToggleFrame('inventory')
				end
			elseif button == 'RightButton' then
				Addon:ShowOptions()
			end
		end,

		OnTooltipShow = function(tooltip)
			tooltip:AddLine(ADDON)
			tooltip:AddLine(L.TipShowInventory, 1, 1, 1)
			tooltip:AddLine(L.TipShowBank, 1, 1, 1)
			tooltip:AddLine(L.TipShowOptions, 1, 1, 1)
		end,
	})
end


--[[ Frames ]]--

function Addon:UpdateFrames()
	self:SendMessage('UPDATE_ALL')
end

function Addon:AreBasicFramesEnabled()
	return self:IsFrameEnabled('inventory') and self:IsFrameEnabled('bank')
end

function Addon:ToggleFrame(id)
	if self:IsFrameEnabled(id) then
		if self:IsFrameShown(id) then
			return self:HideFrame(id, true)
		else
			return self:ShowFrame(id)
		end
	end
end

function Addon:ShowFrame(id)
	if self:IsFrameEnabled(id) then
		self:CreateFrame(id)
		self:GetFrame(id):ShowFrame()
		return true
	end
end

function Addon:HideFrame(id, force)
	if self:IsFrameEnabled(id) then
		self:GetFrame(id):HideFrame(force)
		return true
	end
end

function Addon:CreateFrame(id)
	if self:IsFrameEnabled(id) then
 		self.frames[id] = self.frames[id] or self[id:gsub('^.', id.upper) .. 'Frame']:New(id)
 	end
end

function Addon:IsFrameShown(id)
	local frame = self:GetFrame(id)
	return frame and frame:IsFrameShown()
end

function Addon:IsFrameEnabled(id)
	return not self.sets.frames[id].disabled
end

function Addon:GetFrame(id)
	return self.frames[id]
end


--[[ Bag Buttons Hooks ]]--

function Addon:HookBagClickEvents()
	--inventory
	local canHide = true
	local onMerchantHide = MerchantFrame:GetScript('OnHide')

	local hideInventory = function()
		if canHide then
			self:HideFrame('inventory')
		end
	end

	MerchantFrame:SetScript('OnHide', function(...)
		canHide = false
		onMerchantHide(...)
		canHide = true
	end)

	hooksecurefunc('CloseBackpack', hideInventory)
	hooksecurefunc('CloseAllBags', hideInventory)


	--backpack
	local oOpenBackpack = OpenBackpack
	OpenBackpack = function()
		if not self:ShowFrame('inventory') then
			oOpenBackpack()
		end
	end

	local oToggleBackpack = ToggleBackpack
	ToggleBackpack = function()
		if not self:ToggleFrame('inventory') then
			oToggleBackpack()
		end
	end

	--single bag
	local oToggleBag = ToggleBag
	ToggleBag = function(bag)
		local frame = self:IsBankBag(bag) and 'bank' or 'inventory'
		if not self:ToggleFrame(frame) then
			oToggleBag(bag)
		end
	end

	local oOpenBag = OpenBag
	OpenBag = function(bag)
		local frame = self:IsBankBag(bag) and 'bank' or 'inventory'
		if not self:ShowFrame(frame) then
			oOpenBag(bag)
		end
	end


	--all bags
	local oOpenAllBags = OpenAllBags
	OpenAllBags = function(frame)
		if not self:ShowFrame('inventory') then
			oOpenAllBags(frame)
		end
	end

	if ToggleAllBags then
		local oToggleAllBags = ToggleAllBags
		ToggleAllBags = function()
			if not self:ToggleFrame('inventory') then
				oToggleAllBags()
			end
		end
	end

	local function checkIfInventoryShown(button)
		if self:IsFrameEnabled('inventory') then
			button:SetChecked(self:IsFrameShown('inventory'))
		end
	end

	hooksecurefunc('BagSlotButton_UpdateChecked', checkIfInventoryShown)
	hooksecurefunc('BackpackButton_UpdateChecked', checkIfInventoryShown)
end


--[[ Slash Commands ]]--

function Addon:AddSlashCommands()
	self:RegisterChatCommand(ADDON:lower(), 'HandleSlashCommand')
	self:RegisterChatCommand('bgn', 'HandleSlashCommand')
end

function Addon:HandleSlashCommand(cmd)
	cmd = cmd and cmd:lower() or ''
	
	if cmd == 'bank' then
		self:ToggleFrame('bank')
	elseif cmd == 'bags' or cmd == 'inventory' then
		self:ToggleFrame('inventory')
	elseif cmd == 'version' then
		self:Print(GetAddOnMetadata(ADDON, 'Version'))
	elseif cmd == '?' or cmd == 'help' then
		self:PrintHelp()
	else
		if not self:ShowOptions() and cmd ~= 'config' and cmd ~= 'options' then
			self:PrintHelp()
		end
	end
end

function Addon:PrintHelp()
	local function PrintCmd(cmd, desc)
		print(format(' - |cFF33FF99%s|r: %s', cmd, desc))
	end

	self:Print(L.Commands)
	PrintCmd('bags', L.CmdShowInventory)
	PrintCmd('bank', L.CmdShowBank)
	PrintCmd('version', L.CmdShowVersion)
end
function Addon:ShowOptions()
	if LoadAddOn(ADDON .. '_Config') then
		Addon.GeneralOptions:Open()
		return true
	end
end
