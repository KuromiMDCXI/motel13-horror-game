local Players = game:GetService("Players")

local InventoryService = {}
InventoryService.__index = InventoryService

function InventoryService.new()
	local self = setmetatable({}, InventoryService)
	self._data = {}
	Players.PlayerRemoving:Connect(function(player)
		self._data[player] = nil
	end)
	return self
end

function InventoryService:ResetRound()
	for _, player in ipairs(Players:GetPlayers()) do
		self._data[player] = {
			keys = {},
			fuses = 0,
		}
	end
end

function InventoryService:_get(player: Player)
	if not self._data[player] then
		self._data[player] = { keys = {}, fuses = 0 }
	end
	return self._data[player]
end

function InventoryService:AddKey(player: Player, keyId: number)
	self:_get(player).keys[keyId] = true
end

function InventoryService:HasKey(player: Player, keyId: number): boolean
	return self:_get(player).keys[keyId] == true
end

function InventoryService:AddFuse(player: Player)
	self:_get(player).fuses += 1
end

function InventoryService:GetFuseCount(player: Player): number
	return self:_get(player).fuses
end

return InventoryService
