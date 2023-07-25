local Angle = Angle
local GetConVar = GetConVar
local math_Clamp = math.Clamp
local FindMetaTable = FindMetaTable
local math_min = math.min
local Lerp = Lerp
local math_atan2 = math.atan2
local math_sqrt = math.sqrt
local math_sin = math.sin
local math_cos = math.cos

local ang0 = Angle(0, 0, 0)
SWEP.ClientFreeAimAng = Angle(ang0)

local FreeAimCVar = GetConVar("arccw_freeaim")

function SWEP:ShouldFreeAim()
    if self:GetOwner():IsNPC() then return false end
    if (FreeAimCVar:GetInt() == 0 or self:GetBuff_Override("NeverFreeAim", self.NeverFreeAim))  and !self:GetBuff_Override("AlwaysFreeAim", self.AlwaysFreeAim) then return false end
    return true
end

function SWEP:FreeAimMaxAngle()
    local ang = self.FreeAimAngle and self:GetBuff("FreeAimAngle") or math_Clamp(self:GetBuff("HipDispersion") / 80, 3, 10)
    return ang
end

do
    local ENTITY = FindMetaTable("Entity")
    local entityEyeAngles = ENTITY.EyeAngles

    local ANGLE = FindMetaTable("Angle")
    local angleSub = ANGLE.Sub
    local angleMul = ANGLE.Mul

    local normalizeAngle = math.NormalizeAngle

    function SWEP:ThinkFreeAim()
        local owner = self:GetOwner()
        local eyeAngles = entityEyeAngles(owner)

        if self:ShouldFreeAim() then
            local lastAimAngle = self.dt.LastAimAngle
            local diff = eyeAngles*1

            angleSub(diff, lastAimAngle)

            local freeaimang = lastAimAngle * 1
            local max = self:FreeAimMaxAngle()

            local canshoot = self:CanShootWhileSprint()
            local sightdelta = self:GetSightDelta()

            local delta = math_min(sightdelta, canshoot and 1 or self:GetSprintDelta(), self:GetState() == ArcCW.STATE_CUSTOMIZE and 0 or 1)
    
            if isangle(max) then
                angleMul(max, delta)
            else
                max = max * delta
            end

            diff.p = normalizeAngle(diff.p)
            diff.y = normalizeAngle(diff.y)

            angleMul(diff, Lerp(delta, 1, 0.25))

            freeaimang.p = math_Clamp(normalizeAngle(freeaimang.p) + normalizeAngle(diff.p), -max, max)
            freeaimang.y = math_Clamp(normalizeAngle(freeaimang.y) + normalizeAngle(diff.y), -max, max)

            local p, y = freeaimang.p, freeaimang.y

            local ang2d = math_atan2(p, y)
            local mag2d = math_sqrt(p*p + y*y)

            mag2d = math_min(mag2d, max)

            freeaimang.p = mag2d * math_sin(ang2d)
            freeaimang.y = mag2d * math_cos(ang2d)

            self:SetFreeAimAngle(freeaimang)

            if CLIENT then
                self.ClientFreeAimAng = freeaimang
            end
        end

        self:SetLastAimAngle(eyeAngles)
    end
end

function SWEP:GetFreeAimOffset()
    if !self:ShouldFreeAim() then return ang0 end
    if CLIENT then
        return self.ClientFreeAimAng
    else
        return self:GetFreeAimAngle()
    end
end