-- credits : fesiug for some things

local function CacheAModel(mdl)
    if SERVER then
        if util.IsValidModel(tostring(mdl)) then
            local cmdl = ents.Create("prop_dynamic")
            cmdl:SetModel(mdl)
            cmdl:Spawn()
            cmdl:Remove()
        end
    elseif CLIENT then
        util.PrecacheModel(tostring(mdl))
    end
end

function ArcCW:CacheAttsModels()
    if !ArcCW.AttMdlPrecached then
        print("ArcCW: Starting caching all attachments models assets.")

        local modeltbl = ArcCW.ModelToPrecacheList
        for i = 1, #modeltbl do
            local mdl = modeltbl[i]
            CacheAModel(mdl)
        end

        ArcCW.AttMdlPrecached = true
        print("ArcCW: Done caching attachments models. Pretty heavy isn't it?")
    end
end

ArcCW.PrecachedWepSounds = {}

local WepPossibleSfx = {
    "DropMagazineSounds",
    "ShootSound",
    "ShootSoundSilenced",
    "DistantShootSound",
    "DistantShootSoundSilenced",
    "DistantShootSoundOutdoors",
    "DistantShootSoundIndoors",
    "DistantShootSoundOutdoorsSilenced",
    "DistantShootSoundIndoorsSilenced",
    "ShootDrySound",
    "ShootSoundLooping",
    "MeleeSwingSound",
    "MeleeHitSound",
    "FiremodeSound"
}

local WepPossibleCrucialSfx = {
    "ShootSound",
    "ShootSoundSilenced",
    "DistantShootSound",
    "DistantShootSoundOutdoors",
    "DistantShootSoundIndoors"
}

local function CacheASound(str)
    local ex = string.GetExtensionFromFilename(str)

    if ex == "ogg" or ex == "wav" or ex == "mp3" then
        if SERVER then
            local cmdl = ents.Create("prop_dynamic")
            str = string.Replace(str, "sound\\", "")
            str = string.Replace(str, "sound/", "" )
            cmdl:EmitSound(str, 0, 100, 0.001, CHAN_WEAPON)
            cmdl:Remove()
        else
            local client = LocalPlayer()
            if IsValid(client) then
                client:EmitSound(str, 75, 100, 0.001, CHAN_WEAPON)
            end
        end
    end
end

function ArcCW:CacheWepSounds(wep, class, allsounds)
    if !ArcCW.PrecachedWepSounds[class] then
        local SoundsToPrecacheList = {}
        local tbl = WepPossibleCrucialSfx

        if allsounds then tbl = WepPossibleSfx end

        for i = 1, #tbl do
            local posiblesfx = tbl[i]
            local sfx = wep[posiblesfx]

            if istable(sfx) then
                for i2 = 1, #sfx do
                    local sfxinside = sfx[i2]
                    table.insert(SoundsToPrecacheList, sfxinside)
                end
            elseif isstring(sfx) then
                table.insert(SoundsToPrecacheList, sfx)
            end
        end

        for i = 1, #SoundsToPrecacheList do
            local sfx = SoundsToPrecacheList[i]

            timer.Simple(i * 0.01, function()
                CacheASound(sfx)
            end)
        end
        
        ArcCW.PrecachedWepSounds[class] = true
    end
end

function ArcCW:CacheWeaponsModels()
    if !ArcCW.WepMdlPrecached then
        print("ArcCW: Precaching all weapon models!")

        local weps = weapons.GetList()

        for i = 1, #weps do
            local wep = weps[i]
            if weapons.IsBasedOn(wep.ClassName, "arccw_base") then
                if wep.ViewModel then
                    CacheAModel(wep.ViewModel)
                end
            end
        end

        ArcCW.WepMdlPrecached = true
        print("ArcCW: Finished caching all weapon models, pretty heavy!")
    end
end

function ArcCW:CacheAllSounds()
    local weps = weapons.GetList()

    for i = 1, #weps do
        local wep = weps[i]
        if weapons.IsBasedOn(wep.ClassName, "arccw_base") then
            if wep.ViewModel then
                ArcCW.CacheWepSounds(wep, wep.ClassName, true)
            end
        end
    end
end

function ArcCW:CacheAllCrucialSounds()
    local weps = weapons.GetList()

    for i = 1, #weps do
        local wep = weps[i]
        if weapons.IsBasedOn(wep.ClassName, "arccw_base") then
            if wep.ViewModel then
                ArcCW.CacheWepSounds(wep, wep.ClassName, false)
            end
        end
    end
end

timer.Simple(1, function()
    local cachemodels = GetConVar("arccw_precache_wepmodels_onstartup")
    local cacheatts = GetConVar("arccw_precache_attsmodels_onstartup")
    local cachesounds = GetConVar("arccw_precache_allsounds_onstartup")
    local cachecrucialsounds = GetConVar("arccw_precache_crucialsounds_onstartup")

    if cachemodels:GetBool() then
        ArcCW.CacheWeaponsModels()
    end
    
    if cacheatts:GetBool() then
        ArcCW.CacheAttsModels()
    end

    if cachesounds:GetBool() then
        ArcCW.CacheAllSounds()
    elseif cachecrucialsounds:GetBool() then
        ArcCW.CacheAllCrucialSounds()
    end
end)

concommand.Add("arccw_precache_allsounds", ArcCW.CacheAllSounds)
concommand.Add("arccw_precache_wepmodels", ArcCW.CacheWeaponsModels)
concommand.Add("arccw_precache_attsmodels", ArcCW.CacheAttsModels)