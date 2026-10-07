SWEP.NearWallTick = 0
SWEP.NearWallCached = false

do
    local traceResults = {}

    local traceData = {
        start = true,
        endpos = true,
        filter = true,
        mask = MASK_SHOT_HULL,
        output = traceResults
    }

    local VECTOR = FindMetaTable("Vector")
    local vectorAdd = VECTOR.Add
    local vectorMul = VECTOR.Mul

    local angleForward = FindMetaTable("Angle").Forward
    local entityGetOwner = FindMetaTable("Entity").GetOwner

    local engineTickCount = engine.TickCount
    local math_Clamp = math.Clamp

    function GetcalculatedNearWall(self)
        local length = self:GetProcessedValue("BarrelLength", true)
        local min_length = length / 2

        if length == 0 or min_length == 0 then return 0, false end

        local startPos = self:GetShootPos()
        local endPos = angleForward(self:GetShootDir())
        vectorMul(endPos, length)
        vectorAdd(endPos, startPos)

        traceData.start = startPos
        traceData.endpos = endPos
        traceData.filter = entityGetOwner(self)

        util.TraceLine(traceData)

        local fraction = 0
        local hit = false

        if traceResults.Hit then
            local hit_length = (traceResults.HitPos - startPos):Length()

            if hit_length <= min_length then
                fraction = 1
                hit = true
            elseif hit_length < length then
                fraction = 1 - (hit_length - min_length) / (length - min_length)
            end
        end
        return math_Clamp(fraction, 0, 1), hit
    end

    function SWEP:GetIsNearWall() --уберу хуйня получилась, или доделаю
        local now = engineTickCount()

        if self.NearWallTick == now then return self.NearWallCached end
        if (self.NearWallLastCheck or 0) > now then return self.NearWallCached end
        self.NearWallLastCheck = now + 1

        local fraction, hit = GetcalculatedNearWall(self)

        self.NearWallCached = hit
        self.NearWallTick = now
        self.NearWallFractionCached = fraction

        return hit
    end

    function SWEP:GetNearWallFraction()
        local now = engineTickCount()

        if self.NearWallTick == now and self.NearWallFractionCached then
            return self.NearWallFractionCached
        end
        if (self.NearWallLastCheck or 0) > now and self.NearWallFractionCached then
            return self.NearWallFractionCached
        end

        self.NearWallLastCheck = now + 1

        local fraction, hit = GetcalculatedNearWall(self)

        self.NearWallCached = hit
        self.NearWallFractionCached = fraction
        self.NearWallTick = now

        return fraction
    end
end

local swepGetNearWallFraction = SWEP.GetNearWallFraction
local swepGetIsNearWall = SWEP.GetIsNearWall 
local math_Approach = math.Approach
local math_abs = math.abs
local FrameTime = FrameTime

function SWEP:ThinkNearWall()
    local time = self:GetProcessedValue("SprintToFireTime", true) * 0.75
    local owner = self:GetOwner()
    if owner and math_abs(owner:GetNW2Float("leaning_fraction", 0)) > 0.1 then
        time = 0.1
    end
    -- print(swepGetIsNearWall(self))
    -- print(swepGetNearWallFraction(self))
    local target = swepGetNearWallFraction(self)

    self:SetNearWallAmount(math_Approach(self.dt.NearWallAmount or 0, target, FrameTime() / time)) --nearwalling now not bool, it have a fraction from 0 to 1
end