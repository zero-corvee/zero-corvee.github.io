-- Bunny Guardian client entry point: builds the HUD and hooks up controls.

local Modules = script.Parent:WaitForChild("Modules")
local HUD = require(Modules:WaitForChild("HUD"))
local AbilityInput = require(Modules:WaitForChild("AbilityInput"))

HUD.Init(AbilityInput.Use)
AbilityInput.Init()
