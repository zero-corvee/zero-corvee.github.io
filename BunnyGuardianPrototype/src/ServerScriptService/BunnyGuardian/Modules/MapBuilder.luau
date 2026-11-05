-- MapBuilder: builds the garden, the burrow and the fox spawn points from
-- simple parts. Everything lives inside Workspace.BunnyGuardianMap so it never
-- touches unrelated objects in the place.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BunnyGuardian"):WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

export type MapInfo = {
	Folder: Folder,
	Burrow: BasePart,
	EnemyFolder: Folder,
	EffectsFolder: Folder,
	FoxSpawns: { Vector3 },
}

local function makePart(props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" and key ~= "ClassName" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- A cylinder lying flat on the ground (Roblox cylinders point along X).
local function flatDisk(parent: Instance, name: string, position: Vector3, diameter: number, thickness: number, color: Color3, material: Enum.Material?)
	return makePart({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, diameter, diameter),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = parent,
	})
end

local function buildBurrow(folder: Folder): BasePart
	local burrowModel = Instance.new("Model")
	burrowModel.Name = "Burrow"

	local center = Config.Burrow.Position
	local mound = makePart({
		Name = "Mound",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(14, 14, 14),
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(122, 84, 52),
		Material = Enum.Material.Ground,
		Parent = burrowModel,
	})
	mound:SetAttribute("IsBurrow", true)

	-- Grass cap so it looks like a hill with grass on top.
	makePart({
		Name = "GrassCap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 4, 9),
		CFrame = CFrame.new(center + Vector3.new(0, 5.6, 0)),
		Color = Color3.fromRGB(96, 168, 74),
		Material = Enum.Material.Grass,
		CanCollide = false,
		Parent = burrowModel,
	})

	-- Entrance hole facing the player spawn (+Z).
	makePart({
		Name = "Entrance",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 4.5, 4.5),
		CFrame = CFrame.new(center + Vector3.new(0, 1.6, 6.6)) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(30, 20, 14),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = burrowModel,
	})

	-- Little welcome sign.
	makePart({
		Name = "SignPost",
		Size = Vector3.new(0.4, 3.5, 0.4),
		CFrame = CFrame.new(center + Vector3.new(4.5, 1.75, 8.5)),
		Color = Color3.fromRGB(110, 76, 44),
		Material = Enum.Material.Wood,
		Parent = burrowModel,
	})
	local board = makePart({
		Name = "SignBoard",
		Size = Vector3.new(3.6, 1.6, 0.25),
		CFrame = CFrame.new(center + Vector3.new(4.5, 3.6, 8.5)),
		Color = Color3.fromRGB(196, 150, 96),
		Material = Enum.Material.Wood,
		Parent = burrowModel,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Bunny Burrow\nProtect it!"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(70, 40, 20)
	label.Parent = gui

	burrowModel.PrimaryPart = mound
	burrowModel.Parent = folder
	return mound
end

local function buildFence(folder: Folder, half: number)
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	local wood = Color3.fromRGB(214, 180, 130)
	local step = 8
	for i = -half, half, step do
		for _, pos in { Vector3.new(i, 1.5, -half), Vector3.new(i, 1.5, half), Vector3.new(-half, 1.5, i), Vector3.new(half, 1.5, i) } do
			makePart({ Name = "Post", Size = Vector3.new(0.8, 3, 0.8), CFrame = CFrame.new(pos), Color = wood, Material = Enum.Material.Wood, Parent = fence })
		end
	end
	for _, rail in {
		{ Vector3.new(0, 2.2, -half), Vector3.new(half * 2, 0.4, 0.3) },
		{ Vector3.new(0, 2.2, half), Vector3.new(half * 2, 0.4, 0.3) },
		{ Vector3.new(-half, 2.2, 0), Vector3.new(0.3, 0.4, half * 2) },
		{ Vector3.new(half, 2.2, 0), Vector3.new(0.3, 0.4, half * 2) },
	} do
		makePart({ Name = "Rail", Size = rail[2], CFrame = CFrame.new(rail[1]), Color = wood, Material = Enum.Material.Wood, CanCollide = false, Parent = fence })
	end
	fence.Parent = folder
end

local function buildCarrotPatch(folder: Folder, origin: Vector3)
	local patch = Instance.new("Model")
	patch.Name = "CarrotPatch"
	makePart({
		Name = "Soil",
		Size = Vector3.new(12, 0.3, 8),
		CFrame = CFrame.new(origin + Vector3.new(0, 0.15, 0)),
		Color = Color3.fromRGB(94, 62, 40),
		Material = Enum.Material.Ground,
		CanCollide = false,
		Parent = patch,
	})
	for x = -4.5, 4.5, 3 do
		for z = -2.5, 2.5, 2.5 do
			local base = origin + Vector3.new(x, 0.3, z)
			makePart({ Name = "CarrotTop", Size = Vector3.new(0.6, 0.4, 0.6), CFrame = CFrame.new(base + Vector3.new(0, 0.2, 0)), Color = Color3.fromRGB(240, 130, 30), CanCollide = false, Parent = patch })
			makePart({ Name = "Leaves", Size = Vector3.new(0.3, 1.2, 0.3), CFrame = CFrame.new(base + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(12)), Color = Color3.fromRGB(70, 170, 60), CanCollide = false, Parent = patch })
		end
	end
	patch.Parent = folder
end

local function buildTree(folder: Folder, position: Vector3, scale: number)
	local tree = Instance.new("Model")
	tree.Name = "Tree"
	makePart({ Name = "Trunk", Size = Vector3.new(1.6, 8, 1.6) * scale, CFrame = CFrame.new(position + Vector3.new(0, 4 * scale, 0)), Color = Color3.fromRGB(110, 76, 44), Material = Enum.Material.Wood, Parent = tree })
	makePart({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(9, 9, 9) * scale, CFrame = CFrame.new(position + Vector3.new(0, 10 * scale, 0)), Color = Color3.fromRGB(74, 150, 62), Material = Enum.Material.Grass, Parent = tree })
	tree.Parent = folder
end

local function buildFlowers(folder: Folder, rng: Random)
	local flowers = Instance.new("Model")
	flowers.Name = "Flowers"
	local colors = {
		Color3.fromRGB(255, 120, 170),
		Color3.fromRGB(255, 230, 90),
		Color3.fromRGB(170, 130, 255),
		Color3.fromRGB(255, 255, 255),
	}
	for _ = 1, 70 do
		local pos = Vector3.new(rng:NextNumber(-95, 95), 0, rng:NextNumber(-95, 95))
		-- keep paths and burrow area clear
		if pos.Magnitude > 16 and math.abs(pos.X) > 5 and math.abs(pos.Z) > 5 then
			makePart({ Name = "Stem", Size = Vector3.new(0.2, 1, 0.2), CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(60, 140, 50), CanCollide = false, Parent = flowers })
			makePart({ Name = "Bloom", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = CFrame.new(pos + Vector3.new(0, 1.1, 0)), Color = colors[rng:NextInteger(1, #colors)], Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = flowers })
		end
	end
	flowers.Parent = folder
end

local function buildPaths(folder: Folder, half: number)
	local paths = Instance.new("Model")
	paths.Name = "DirtPaths"
	local dirt = Color3.fromRGB(176, 140, 96)
	makePart({ Name = "PathNS", Size = Vector3.new(7, 0.1, half * 2), CFrame = CFrame.new(0, 0.05, 0), Color = dirt, Material = Enum.Material.Sand, CanCollide = false, Parent = paths })
	makePart({ Name = "PathEW", Size = Vector3.new(half * 2, 0.1, 7), CFrame = CFrame.new(0, 0.05, 0), Color = dirt, Material = Enum.Material.Sand, CanCollide = false, Parent = paths })
	flatDisk(paths, "Clearing", Vector3.new(0, 0.06, 0), 26, 0.1, dirt, Enum.Material.Sand)
	paths.Parent = folder
end

local function buildFoxDens(folder: Folder, spawns: { Vector3 })
	local dens = Instance.new("Model")
	dens.Name = "FoxDens"
	for i, pos in spawns do
		makePart({
			Name = "FoxDen" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(10, 6, 10),
			CFrame = CFrame.new(pos + Vector3.new(0, 0, 0)),
			Color = Color3.fromRGB(60, 90, 50),
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = dens,
		})
		flatDisk(dens, "DenMarker" .. i, pos + Vector3.new(0, 0.08, 0), 12, 0.1, Color3.fromRGB(150, 60, 40))
	end
	dens.Parent = folder
end

function MapBuilder.Build(): MapInfo
	local folder = getOrCreateFolder(Workspace, "BunnyGuardianMap")
	local half = 100
	local spawns = {
		Vector3.new(0, 0, -half + 6),
		Vector3.new(half - 6, 0, 0),
		Vector3.new(-half + 6, 0, 0),
		Vector3.new(half - 14, 0, half - 14),
		Vector3.new(-half + 14, 0, -half + 14),
	}

	local garden = folder:FindFirstChild("Garden")
	local burrow: BasePart
	if garden then
		-- Already built (e.g. saved into the place); reuse it.
		local existing = garden:FindFirstChild("Burrow")
		burrow = (existing and (existing :: Model).PrimaryPart) :: BasePart
	end

	if not burrow then
		if garden then
			garden:Destroy()
		end
		local newGarden = Instance.new("Folder")
		newGarden.Name = "Garden"
		local rng = Random.new(42)
		buildPaths(newGarden, half)
		buildFence(newGarden, half)
		buildCarrotPatch(newGarden, Vector3.new(-22, 0, 22))
		buildCarrotPatch(newGarden, Vector3.new(22, 0, 22))
		buildCarrotPatch(newGarden, Vector3.new(-22, 0, -22))
		buildCarrotPatch(newGarden, Vector3.new(22, 0, -22))
		for _, pos in { Vector3.new(-70, 0, -40), Vector3.new(65, 0, 45), Vector3.new(-55, 0, 70), Vector3.new(70, 0, -70), Vector3.new(-80, 0, 30), Vector3.new(40, 0, 80) } do
			buildTree(newGarden, pos, rng:NextNumber(0.8, 1.3))
		end
		buildFlowers(newGarden, rng)
		buildFoxDens(newGarden, spawns)
		burrow = buildBurrow(newGarden)
		newGarden.Parent = folder
	end

	local enemyFolder = getOrCreateFolder(folder, "Enemies")
	local effectsFolder = getOrCreateFolder(folder, "Effects")
	enemyFolder:ClearAllChildren()
	effectsFolder:ClearAllChildren()

	return {
		Folder = folder,
		Burrow = burrow,
		EnemyFolder = enemyFolder,
		EffectsFolder = effectsFolder,
		FoxSpawns = spawns,
	}
end

return MapBuilder
