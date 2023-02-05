SWEP.Cam_Offset_Ang = Angle(0, 0, 0)

local isSingleplayer = game.SinglePlayer()

do
    local cvarArccwNoinspect = GetConVar("arccw_noinspect")
    local cvarGetBool = FindMetaTable("ConVar").GetBool

    local playerGetInfoNum = FindMetaTable("Player").GetInfoNum
    
    -- I hate this function
    function SWEP:SelectAnimation(anim)
        local nwState = self.dt.NWState
        local animations = self.Animations
    
        if nwState == ArcCW.STATE_SIGHTS then
            if animations[anim .. "_iron"] then
                anim = anim .. "_iron"
            end
            if animations[anim .. "_sights"] then
                anim = anim .. "_sights"
            end
            if animations[anim .. "_sight"] then
                anim = anim .. "_sight"
            end
        elseif nwState == ArcCW.STATE_SPRINT and animations[anim .. "_sprint"] and not self:CanShootWhileSprint() then
            anim = anim .. "_sprint"
        end
    
        if animations[anim .. "_bipod"] and self:InBipod() then
            anim = anim .. "_bipod"
        end
    
        if nwState == ArcCW.STATE_CUSTOMIZE and animations[anim .. "_inspect"]
            and ((CLIENT and not cvarGetBool(cvarArccwNoinspect))
            or (SERVER and playerGetInfoNum(self:GetOwner(), "arccw_noinspect", 0))) 
        then
            anim = anim .. "_inspect"
        end
    
        if (self:Clip1() == 0 or (self:HasBottomlessClip() and self:Ammo1() == 0)) and animations[anim .. "_empty"] then
            anim = anim .. "_empty"
        end
    
        if self:GetMalfunctionJam() and animations[anim .. "_jammed"] then
            anim = anim .. "_jammed"
        end
    
        if self:GetBuff_Override("Override_TriggerDelay", self.TriggerDelay) and self:IsTriggerHeld() and animations[anim .. "_trigger"] then
            anim = anim .. "_trigger"
        end
    
        if not animations[anim] then return end
    
        return anim
    end
end

SWEP.LastAnimStartTime = 0
SWEP.LastAnimFinishTime = 0

function SWEP:PlayAnimationEZ(key, mult, priority)
    return self:PlayAnimation(key, mult, true, 0, false, false, priority, false)
end

local inf = math.huge
local minf = -inf

do
    local PLAYER = FindMetaTable("Player")
    local playerGetViewModel = PLAYER.GetViewModel
    local playerAddVCDSequenceToGestureSlot = PLAYER.AddVCDSequenceToGestureSlot

    local ENTITY = FindMetaTable("Entity")
    local entityLookupSequence = ENTITY.LookupSequence
    local entitySelectWeightedSequence = ENTITY.SelectWeightedSequence
    local entityGetPos = ENTITY.GetPos
    local entitySendViewModelMatchingSequence = ENTITY.SendViewModelMatchingSequence
    local entitySequenceDuration = ENTITY.SequenceDuration
    local entitySetPlaybackRate = ENTITY.SetPlaybackRate
    local entityGetAttachment = ENTITY.GetAttachment
    local entityWorldToLocalAngles = ENTITY.WorldToLocalAngles

    local util_SharedRandom = util.SharedRandom

    function SWEP:PlayAnimation(key, mult, pred, startfrom, tt, skipholster, priority, absolute)
        mult = mult or 1
        pred = pred or false
        startfrom = startfrom or 0
        tt = tt or false
        --skipholster = skipholster or false Unused
        priority = priority or false
        absolute = absolute or false
        if not key then return end

        local ct = CurTime()

        if self:GetPriorityAnim() and not priority then return end

        local owner = self:GetOwner()
        local ownerIsPlayer = owner:IsPlayer()

        if isSingleplayer and SERVER and pred then
            net.Start("arccw_sp_anim")
            net.WriteString(key)
            net.WriteFloat(mult)
            net.WriteFloat(startfrom)
            net.WriteBool(tt)
            --net.WriteBool(skipholster) Unused
            net.WriteBool(priority)
            net.Send(owner)
        end

        local anim = self.Animations[key]
        if not anim then return end
        local tranim = self:GetBuff_Hook("Hook_TranslateAnimation", key)
        if self.Animations[tranim] then
            key = tranim
            anim = self.Animations[tranim]
        --[[elseif self.Animations[key] then -- Can't do due to backwards compatibility... unless you have a better idea?
            anim = self.Animations[key]
        else
            return]]
        end
    
        local isFirstTimePredicted = IsFirstTimePredicted()

        if CLIENT and anim.ViewPunchTable then
            for k, v in ipairs(anim.ViewPunchTable) do
    
                if !v.t then continue end
    
                local st = (v.t * mult) - startfrom
    
                if st >= 0 and isnumber(v.t) and ownerIsPlayer and (isSingleplayer or isFirstTimePredicted) then
                    self:SetTimer(st, function() self:OurViewPunch(v.p or vector_origin) end, id)
                end
            end
        end

        if isnumber(anim.ShellEjectAt) then
            self:SetTimer(anim.ShellEjectAt * mult, function()
                local num = 1
                if self.RevolverReload then
                    num = self.Primary.ClipSize - self:Clip1()
                end
                for i = 1, num do
                    self:DoShellEject()
                end
            end)
        end

        if not owner then return end
        if not owner.GetViewModel then return end
        local vm = playerGetViewModel(owner)
    
        if not IsValid(vm) then return end

        local now = CurTime()

        local seq = anim.Source
        if anim.RareSource and util_SharedRandom("raresource", 0, 1, now) < (1 / (anim.RareSourceChance or 100)) then
            seq = anim.RareSource
        end
        seq = self:GetBuff_Hook("Hook_TranslateSequence", seq)

        if istable(seq) then
            seq["BaseClass"] = nil
            seq = seq[math.Round(util_SharedRandom("randomseq" .. now, 1, #seq))]
        end

        if isstring(seq) then
            seq = entityLookupSequence(vm, seq)
        end

        local time = absolute and 1 or self:GetAnimKeyTime(key)
        local timeMult = time * mult
        local ttime = timeMult - startfrom

        -- if startfrom > timeMult then return end
        if ttime < 0 then
            return
        end

        if tt then
            self:SetNextPrimaryFire(ct + ((anim.MinProgress or time) * mult) - startfrom)
        end

        if anim.LHIK then
            self.LHIKStartTime = ct
            self.LHIKEndTime = ct + ttime

            if anim.LHIKTimeline then
                -- self.LHIKTimeline = {}
                local timeline = {}
                local animTimeline = anim.LHIKTimeline
                for i = 1, #animTimeline do
                    timeline[i] = animTimeline[i]
                end

                self.LHIKTimeline = timeline
            else
                local lhikInDefault = anim.LHIKIn or 0.1
                local lhikOutDefault = anim.LHIKOut or 0.1

                self.LHIKTimeline = {
                    {t = minf, lhik = 1},
                    {t = (lhikInDefault - (anim.LHIKEaseIn or lhikInDefault)) * mult, lhik = 1},
                    {t = lhikInDefault * mult, lhik = 0},
                    {t = ttime - (lhikOutDefault * mult), lhik = 0},
                    {t = ttime - ((lhikOutDefault - (anim.LHIKEaseOut or lhikOutDefault)) * mult), lhik = 1},
                    {t = inf, lhik = 1}
                }

                if anim.LHIKIn == 0 then
                    self.LHIKTimeline[1].lhik = minf
                    self.LHIKTimeline[2].lhik = minf
                end

                if anim.LHIKOut == 0 then
                    local len = #self.LHIKTimeline
                    self.LHIKTimeline[len - 1].lhik = inf
                    self.LHIKTimeline[len].lhik = inf
                end
            end
        else
            self.LHIKTimeline = nil
        end

        if anim.LastClip1OutTime then
            self.LastClipOutTime = ct + ((anim.LastClip1OutTime * mult) - startfrom)
        end

        if anim.TPAnim then
            local aseq = entitySelectWeightedSequence(owner, anim.TPAnim)
            if aseq then
                playerAddVCDSequenceToGestureSlot(owner, GESTURE_SLOT_ATTACK_AND_RELOAD, aseq, anim.TPAnimStartTime or 0, true)
                if !isSingleplayer and SERVER then
                    net.Start("arccw_networktpanim")
                        net.WriteEntity(owner)
                        net.WriteUInt(aseq, 16)
                        net.WriteFloat(anim.TPAnimStartTime or 0)
                    net.SendPVS(entityGetPos(owner))
                end
            end
        end

        if not (isSingleplayer and CLIENT) then
            if isSingleplayer or isFirstTimePredicted then
                self:PlaySoundTable(anim.SoundTable or {}, 1 / mult, startfrom, key)
            end
        end

        if seq then
            entitySendViewModelMatchingSequence(vm, seq)
            local dur = entitySequenceDuration(vm)
            entitySetPlaybackRate(vm, math.Clamp(dur / (ttime + startfrom), -4, 12))
            self.LastAnimStartTime = ct
            self.LastAnimFinishTime = ct + dur
            self.LastAnimKey = key
        end

        local att = self:GetBuff_Override("Override_CamAttachment") or self.CamAttachment -- why is this here if we just... do cool stuff elsewhere?
        if att then
            local attachmentData = entityGetAttachment(vm, att)
            if attachmentData then
                self.Cam_Offset_Ang = entityWorldToLocalAngles(vm, attachmentData.Ang)
            end
        end

        self:SetNextIdle(now + ttime)

        return true
    end
end

function SWEP:PlayIdleAnimation(pred)
    local swepDt = self.dt

    local ianim = self:SelectAnimation("idle")
    if swepDt.GrenadePrimed then
        ianim = self:GetGrenadeAlt() and self:SelectAnimation("pre_throw_hold_alt") or self:SelectAnimation("pre_throw_hold")
    end

    local inUBGL = swepDt.InUBGL
    -- (key, mult, pred, startfrom, tt, skipholster, ignorereload)
    if inUBGL and self:GetBuff_Override("UBGL_BaseAnims")
        and self.Animations.idle_ubgl_empty and self:Clip2() <= 0 
    then
        ianim = "idle_ubgl_empty"
    elseif inUBGL and self.Animations.idle_ubgl and self:GetBuff_Override("UBGL_BaseAnims") then
        ianim = "idle_ubgl"
    end

    if self.LastAnimKey ~= ianim then
        ianim = self:GetBuff_Hook("Hook_IdleReset", ianim) or ianim
    end

    self:PlayAnimation(ianim, 1, pred, nil, nil, nil, true)
end

function SWEP:GetAnimKeyTime(key, min)
    if !self:GetOwner() then return 1 end

    local anim = self.Animations[key]

    if !anim then return 1 end

    if self:GetOwner():IsNPC() then return anim.Time or 1 end

    local vm = self:GetOwner():GetViewModel()

    if !vm or !IsValid(vm) then return 1 end

    local t = anim.Time
    if !t then
        local tseq = anim.Source

        if istable(tseq) then
            tseq["BaseClass"] = nil -- god I hate Lua inheritance
            tseq = tseq[1]
        end

        if !tseq then return 1 end
        tseq = vm:LookupSequence(tseq)

        -- to hell with it, just spits wrong on draw sometimes
        t = vm:SequenceDuration(tseq) or 1
    end

    if min and anim.MinProgress then
        t = anim.MinProgress
    end

    if anim.Mult then
        t = t * anim.Mult
    end

    return t
end

if CLIENT then
    net.Receive("arccw_networktpanim", function()
        local ent = net.ReadEntity()
        local aseq = net.ReadUInt(16)
        local starttime = net.ReadFloat()
        if ent ~= LocalPlayer() then
            ent:AddVCDSequenceToGestureSlot( GESTURE_SLOT_ATTACK_AND_RELOAD, aseq, starttime, true )
        end
    end)
end

function SWEP:QueueAnimation() end
function SWEP:NextAnimation() end