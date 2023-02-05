local size = 0
local clump_inner = Material("arccw/hud/clump_inner.png", "mips smooth")
local clump_outer = Material("arccw/hud/clump_outer.png", "mips smooth")
local aimtr_result = {}
local aimtr = {}
local square_mat = Material("color")

function SWEP:ShouldDrawCrosshair()
    if GetConVar("arccw_override_crosshair_off"):GetBool() then return false end
    if !GetConVar("arccw_crosshair"):GetBool() then return false end
    if self:GetReloading() then return false end
    if self:BarrelHitWall() > 0 then return false end
    local asight = self:GetActiveSights()

    if !self:GetOwner():ShouldDrawLocalPlayer()
            and self:GetState() == ArcCW.STATE_SIGHTS and !asight.CrosshairInSights then
        return false
    end

    local nwState = self.dt.NWState
    if nwState == ArcCW.STATE_CUSTOMIZE or 
        nwState == ArcCW.STATE_DISABLE or 
        (nwState == ArcCW.STATE_SPRINT and not self:CanShootWhileSprint())
    then
        return false
    end

    if self:GetCurrentFiremode().Mode == 0 then return false end
    if self:GetBuff_Hook("Hook_ShouldNotFire") then return false end
    return true
end

local cr_main = Color( 0, 255, 0 )
local cr_shad = Color( 0, 0, 0, 127 )

local gaA = 0
local gaD = 0

function SWEP:GetFOVAcc( acc, disp )
    cam.Start3D()
        local eyePos = EyePos()
        local eyeAngles = EyeAngles()
        local eyeAnglesForward = eyeAngles:Forward()
        local eyeAnglesUp = eyeAngles:Up()

        eyePos:Add(eyeAnglesForward)
        local lool = (eyePos + (ArcCW.MOAToAcc * (acc or self:GetBuff("AccuracyMOA"))) * eyeAnglesUp):ToScreen()

        eyeAnglesUp:Mul((disp or self:GetDispersion()) * ArcCW.MOAToAcc / 10)
        eyeAnglesUp:Add(eyePos)

        local lool2 = eyeAnglesUp:ToScreen()
    cam.End3D()

    local halfScrH = ScrH() / 2
    local change = halfScrH * FrameTime()
    local gau = 0

    gau = halfScrH - lool.y
    gaA = math.Approach(gaA, gau, change)
    gau = halfScrH - lool2.y
    gaD = math.Approach(gaD, gau, change)

    return gaA, gaD
end

do
    local white = Color(255, 255, 255, 255)
    local red = Color(255, 50, 50, 255)
    local red2 = Color(255, 0, 0, 255)
    local blue = Color(50, 50, 255, 255)
    local green = Color(50, 255, 50, 255)

    local arccw_crosshair_static = GetConVar("arccw_crosshair_static")
    local arccw_crosshair_dot = GetConVar("arccw_crosshair_dot")
    local arccw_crosshair_prong_top = GetConVar("arccw_crosshair_prong_top")
    local arccw_crosshair_prong_left = GetConVar("arccw_crosshair_prong_left")
    local arccw_crosshair_prong_right = GetConVar("arccw_crosshair_prong_right")
    local arccw_crosshair_prong_bottom = GetConVar("arccw_crosshair_prong_bottom")
    local arccw_crosshair_length = GetConVar("arccw_crosshair_length")
    local arccw_crosshair_thickness = GetConVar("arccw_crosshair_thickness")
    local arccw_crosshair_outline = GetConVar("arccw_crosshair_outline")
    local arccw_crosshair_tilt = GetConVar("arccw_crosshair_tilt")
    local arccw_crosshair_clr_r = GetConVar("arccw_crosshair_clr_r")
    local arccw_crosshair_clr_g = GetConVar("arccw_crosshair_clr_g")
    local arccw_crosshair_clr_b = GetConVar("arccw_crosshair_clr_b")
    local arccw_crosshair_clr_a = GetConVar("arccw_crosshair_clr_a")

    local arccw_crosshair_aa = GetConVar("arccw_crosshair_aa")
    local arccw_aimassist = GetConVar("arccw_aimassist")
    local arccw_aimassist_cl = GetConVar("arccw_aimassist_cl")

    local arccw_crosshair_outline_r = GetConVar("arccw_crosshair_outline_r")
    local arccw_crosshair_outline_g = GetConVar("arccw_crosshair_outline_g")
    local arccw_crosshair_outline_b = GetConVar("arccw_crosshair_outline_b")
    local arccw_crosshair_outline_a = GetConVar("arccw_crosshair_outline_a")

    local arccw_crosshair_gap = GetConVar("arccw_crosshair_gap")
    local arccw_crosshair_trueaim = GetConVar("arccw_crosshair_trueaim")
    local arccw_crosshair_equip = GetConVar("arccw_crosshair_equip")
    local arccw_crosshair_shotgun = GetConVar("arccw_crosshair_shotgun")
    local arccw_crosshair_clump = GetConVar("arccw_crosshair_clump")
    local arccw_crosshair_clump_always = GetConVar("arccw_crosshair_clump_always")
    local arccw_crosshair_clump_outline = GetConVar("arccw_crosshair_clump_outline")

    local CONVAR = FindMetaTable("ConVar")
    local cvarGetBool = CONVAR.GetBool
    local cvarGetInt = CONVAR.GetInt
    local cvarGetFloat = CONVAR.GetFloat

    -- to be modified
    local clr = Color(0, 0, 0, 255)
    local outlineClr = Color(0, 0, 0, 255)

    local function copyColor(from, to)
        to.r = from.r
        to.g = from.g
        to.b = from.b
        to.a = from.a
    end

    function SWEP:DoDrawCrosshair(x, y)
        local ply = LocalPlayer()
        local pos = ply:EyePos()
        local ang = ply:EyeAngles() - self:GetOurViewPunchAngles() + self:GetFreeAimOffset()
    
        if self:GetBuff_Hook("Hook_PreDrawCrosshair") then return end
    
        local static = cvarGetBool(arccw_crosshair_static)
    
        local prong_dot = cvarGetBool(arccw_crosshair_dot)
        local prong_top = cvarGetBool(arccw_crosshair_prong_top)
        local prong_left = cvarGetBool(arccw_crosshair_prong_left)
        local prong_right = cvarGetBool(arccw_crosshair_prong_right)
        local prong_down = cvarGetBool(arccw_crosshair_prong_bottom)

        local prong_len = cvarGetFloat(arccw_crosshair_length)
        local prong_wid = cvarGetFloat(arccw_crosshair_thickness)
        local prong_out = cvarGetInt(arccw_crosshair_outline)
        local prong_tilt = cvarGetBool(arccw_crosshair_tilt)
        
        clr.r = cvarGetInt(arccw_crosshair_clr_r)
        clr.g = cvarGetInt(arccw_crosshair_clr_g)
        clr.b = cvarGetInt(arccw_crosshair_clr_b)
    
        local arccw_ttt_rolecrosshair = GetConVar("arccw_ttt_rolecrosshair")
        if arccw_ttt_rolecrosshair and cvarGetBool(arccw_ttt_rolecrosshair) then
            local roundState = GetRoundState()
            if roundState == ROUND_PREP or roundState == ROUND_POST then
                copyColor(white, clr)
            elseif ply.GetRoleColor and ply:GetRoleColor() then
                clr = ply:GetRoleColor() -- TTT2 feature
            elseif ply:IsActiveTraitor() then
                copyColor(red, clr)
            elseif ply:IsActiveDetective() then
                copyColor(blue, clr)
            else
                copyColor(green, clr)
            end
        end
        if ply.ArcCW_AATarget != nil and cvarGetBool(arccw_crosshair_aa) and cvarGetBool(arccw_aimassist) and cvarGetBool(arccw_aimassist_cl) then
                -- whooie
            copyColor(red2, clr)
        end
        clr.a = cvarGetInt(arccw_crosshair_clr_a)

        outlineClr.r = cvarGetInt(arccw_crosshair_outline_r)
        outlineClr.g = cvarGetInt(arccw_crosshair_outline_g)
        outlineClr.b = cvarGetInt(arccw_crosshair_outline_b)
        outlineClr.a = cvarGetInt(arccw_crosshair_outline_a)
    
        local gA, gD = self:GetFOVAcc( self:GetBuff("AccuracyMOA"), self:GetDispersion() )
        local gap = (static and 8 or gD) * cvarGetFloat(arccw_crosshair_gap)
    
        gap = gap + ( ScreenScale(8) * math.Clamp(self.RecoilAmount, 0, 1) )
    
        local prong = ScreenScale(prong_len)
        local p_w = ScreenScale(prong_wid)
        local p_w2 = p_w + prong_out
    
        local sp
        if self:GetOwner():ShouldDrawLocalPlayer() then
            local tr = util.GetPlayerTrace(self:GetOwner())
            local trace = util.TraceLine( tr )
    
            cam.Start3D()
            local coords = trace.HitPos:ToScreen()
            coords.x = math.Round(coords.x)
            coords.y = math.Round(coords.y)
            cam.End3D()
            sp = { visible = true, x = coords.x, y = coords.y }
        end
    
        cam.Start3D()
        sp = (pos + (ang:Forward() * 3200)):ToScreen()
        cam.End3D()
    
        if GetConVar("arccw_crosshair_trueaim"):GetBool() then
            aimtr.start = self:GetShootSrc()
        else
            aimtr.start = pos
        end
    
        aimtr.endpos = aimtr.start + ((ply:EyeAngles() + self:GetFreeAimOffset()):Forward() * 100000)
        aimtr.filter = {ply}
        aimtr.output = aimtr_result
    
        table.Add(aimtr.filter, ArcCW:GetVehicleFilter(ply) or {})
    
        util.TraceLine(aimtr)
    
        cam.Start3D()
        local w2s = aimtr_result.HitPos:ToScreen()
        w2s.x = math.Round(w2s.x)
        w2s.y = math.Round(w2s.y)
        cam.End3D()
    
        sp.x = w2s.x sp.y = w2s.y
        x, y = sp.x, sp.y
    
        local st = self:GetSightTime() / 2
    
        if self:ShouldDrawCrosshair() then
            self.CrosshairDelta = math.Approach(self.CrosshairDelta or 0, 1, FrameTime() * 1 / st)
        else
            self.CrosshairDelta = math.Approach(self.CrosshairDelta or 0, 0, FrameTime() * 1 / st)
        end
    
        if cvarGetBool(arccw_crosshair_equip) and (self:GetBuff("ShootEntity", true) or self.PrimaryBash) then
            prong = ScreenScale(prong_wid)
            p_w = ScreenScale(prong_wid)
            p_w2 = p_w + prong_out
        end
    
        if prong_dot then
            surface.SetDrawColor(outlineClr.r, outlineClr.g, outlineClr.b, outlineClr.a * self.CrosshairDelta)
            surface.DrawRect(x - p_w2 / 2, y - p_w2 / 2, p_w2, p_w2)
    
            surface.SetDrawColor(clr.r, clr.g, clr.b, clr.a * self.CrosshairDelta)
            surface.DrawRect(x - p_w / 2, y - p_w / 2, p_w, p_w)
        end
    
    
        size = math.Approach(size, gap, FrameTime() * 32 * gap)
        gap = size
        if !static then gap = gap * self.CrosshairDelta end
        gap = math.max(4, gap)
    
        local num = self:GetBuff("Num")
        if GetConVar("arccw_crosshair_shotgun"):GetBool() and num > 1 then
            prong = ScreenScale(prong_wid)
            p_w = ScreenScale(prong_len)
            p_w2 = p_w + prong_out
        end
    
        local prong2 = prong + prong_out
        if prong_tilt then
            local angle = (prong_left and prong_top and prong_right and prong_down) and 45 or 30
            local rad = math.rad(angle)
            local dx = gap * math.cos(rad) + prong * math.cos(rad) / 2
            local dy = gap * math.sin(rad) + prong * math.sin(rad) / 2
            surface.SetMaterial(square_mat)
            -- Shade
            surface.SetDrawColor(outlineClr.r, outlineClr.g, outlineClr.b, outlineClr.a * self.CrosshairDelta)
            if prong_left and prong_top then
                surface.DrawTexturedRectRotated(x - dx, y - dy, prong2, p_w2, -angle)
                surface.DrawTexturedRectRotated(x + dx, y - dy, prong2, p_w2, angle)
            elseif prong_left or prong_top then
                surface.DrawRect(x - p_w2 / 2, y - gap - prong2 + prong_out / 2, p_w2, prong2)
            end
            if prong_right and prong_down then
                surface.DrawTexturedRectRotated(x + dx, y + dy, prong2, p_w2, -angle)
                surface.DrawTexturedRectRotated(x - dx, y + dy, prong2, p_w2, angle)
            elseif prong_right or prong_down then
                surface.DrawRect(x - p_w2 / 2, y + gap - prong_out / 2, p_w2, prong2)
            end
            -- Fill
            surface.SetDrawColor(clr.r, clr.g, clr.b, clr.a * self.CrosshairDelta)
            if prong_left and prong_top then
                surface.DrawTexturedRectRotated(x - dx, y - dy, prong, p_w, -angle)
                surface.DrawTexturedRectRotated(x + dx, y - dy, prong, p_w, angle)
            elseif prong_left or prong_top then
                surface.DrawRect(x - p_w / 2, y - gap - prong, p_w, prong)
            end
            if prong_right and prong_down then
                surface.DrawTexturedRectRotated(x + dx, y + dy, prong, p_w, -angle)
                surface.DrawTexturedRectRotated(x - dx, y + dy, prong, p_w, angle)
            elseif prong_right or prong_down then
                surface.DrawRect(x - p_w / 2, y + gap, p_w, prong)
            end
        else
            -- Shade
            surface.SetDrawColor(outlineClr.r, outlineClr.g, outlineClr.b, outlineClr.a * self.CrosshairDelta)
            if prong_left then
                surface.DrawRect(x - gap - prong2 + prong_out / 2, y - p_w2 / 2, prong2, p_w2)
            end
            if prong_right then
                surface.DrawRect(x + gap - prong_out / 2, y - p_w2 / 2, prong2, p_w2)
            end
            if prong_top then
                surface.DrawRect(x - p_w2 / 2, y - gap - prong2 + prong_out / 2, p_w2, prong2)
            end
            if prong_down then
                surface.DrawRect(x - p_w2 / 2, y + gap - prong_out / 2, p_w2, prong2)
            end
            -- Fill
            surface.SetDrawColor(clr.r, clr.g, clr.b, clr.a * self.CrosshairDelta)
            if prong_left then
                surface.DrawRect(x - gap - prong, y - p_w / 2, prong, p_w)
            end
            if prong_right then
                surface.DrawRect(x + gap, y - p_w / 2, prong, p_w)
            end
            if prong_top then
                surface.DrawRect(x - p_w / 2, y - gap - prong, p_w, prong)
            end
            if prong_down then
                surface.DrawRect(x - p_w / 2, y + gap, p_w, prong)
            end
        end
    
        if cvarGetBool(arccw_crosshair_clump) and (cvarGetBool(arccw_crosshair_clump_always) or num > 1) then
            local acc = math.max(1, gA)
            if cvarGetBool(arccw_crosshair_clump_outline) then
                surface.SetMaterial(clump_outer)
    
                for i=1, prong_out do
                    surface.DrawCircle(x-1, y-0, acc + math.ceil(i*0.5) * (i % 2 == 1 and 1 or -1), outlineClr.r, outlineClr.g, outlineClr.b, outlineClr.a * self.CrosshairDelta)
                end
                surface.DrawCircle(x-1, y-0, acc, outlineClr.r, outlineClr.g, outlineClr.b, outlineClr.a * self.CrosshairDelta)
            end
    
            surface.DrawCircle(x-1, y-0, acc, clr.r, clr.g, clr.b, clr.a * self.CrosshairDelta)
        end
    
        self:GetBuff_Hook("Hook_PostDrawCrosshair", w2s)
    
        return true
    end
end