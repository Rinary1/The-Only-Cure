local function CheckIfPlayerIsInfected(player, toc_data)

    local body_damage = player:getBodyDamage()

    -- Check for amputable limbs
    for _, v in ipairs(GetLimbsBodyPartTypes()) do
        local part_name = TocGetPartNameFromBodyPartType(v)
        local part_data = toc_data.Limbs[part_name]
        local body_part = body_damage:getBodyPart(v)


        if body_part:bitten() and part_data ~= nil then
            if part_data.is_cut == false then
                part_data.is_infected = true

            end

        end
    end

    -- Check for everything else
    for _, v in ipairs(GetOtherBodyPartTypes()) do
        if body_damage:getBodyPart(v):bitten() then
            toc_data.Limbs.is_other_bodypart_infected = true -- Even one is enough, stop cycling if we find it
            break
        end
    end
end




--Helper function for UpdatePlayerHealth
local function SetHealthStatusForBodyPart(part_data, part_name, player)


    -- In case the player gets bit in a cut area, we have to heal him...



    local body_damage = player:getBodyDamage()
    local body_part = body_damage:getBodyPart(TocGetBodyPartFromPartName(part_name))
    if not body_part then
        print("TOC ERROR : Can't update health of " .. part_name);
        return false
    end

    -- Check bandages
    local is_bandaged = false
    local bandage_life = 0
    local bandage_type = ""

    -- TODO Bandages should have some disadvantage when not operated... Like getting drenched or something
    if body_part:bandaged() then
        is_bandaged = true -- this is useless
        bandage_life = body_part:getBandageLife()
        bandage_type = body_part:getBandageType()

    end

    -- Set max health for body part
    if part_data[part_name].is_cicatrized and body_part:getHealth() > 80 then
        body_part:SetHealth(80)
    elseif body_part:getHealth() > 40 then
        body_part:SetHealth(40)
    end

    -- Cicatrization check
    if part_data[part_name].is_cut and not part_data[part_name].is_cicatrized then
        if part_data[part_name].cicatrization_time < 0 then
            part_data[part_name].is_cicatrized = true

            -- TODO make this random if the player gets it or not

            if (not player:HasTrait("Brave")) and ZombRand(1, 11) > 5 then
                player:getTraits():add("Brave")

            end

            if (not player:HasTrait("Insensitive")) and ZombRand(1, 11) > 5 then
                player:getTraits():add("Insensitive")
            end

            -- if the player gets attacked and damaged in a cut area we have to reset it here since it doesn't make any sense
            body_part:setBleeding(false);
            body_part:setDeepWounded(false)
            body_part:setBleedingTime(0)
            body_part:setDeepWoundTime(0)
            body_part:SetBitten(false)
            body_part:setBiteTime(0)
            part_data.is_infected = false


        end
    end

    -- Phantom Pain
    if part_data[part_name].is_amputation_shown and ZombRand(1, 100) < 10 then
        local added_pain
        if part_data[part_name].is_cauterized then added_pain = 60 else added_pain = 30 end
        body_part:setAdditionalPain(ZombRand(1, added_pain))
    end

    -- Reapplies bandages after the whole ordeal
    -- TODO not sure if this still works
    --body_part_type:setBandaged(true, bandage_life, false, bandage_type)
end


local function UpdatePlayerHealth(player, part_data)
    local body_damage = player:getBodyDamage()



    if player:HasTrait("Insensitive") then body_damage:setPainReduction(49) end

    for _, part_name in pairs(GetBodyParts()) do
        if part_data[part_name].is_cut then
            SetHealthStatusForBodyPart(part_data, part_name, player)

        end
    end
end

-- MAIN UPDATE FUNCTIONS

local function TocUpdateEveryOneMinute()

    local player = getPlayer()
    -- To prevent errors during loading
    if player == nil then
        return
    end

    local toc_data = player:getModData().TOC

    if toc_data ~= nil then
        CheckIfPlayerIsInfected(player, toc_data)
        UpdatePlayerHealth(player, toc_data.Limbs)
    end



    -- Updates toc data in a global way, basically player:transmitModData but it works
    -- Sends only Limbs since the other stuff is mostly static
    if toc_data ~= nil then
        -- TODO make it so that we dont send it constantly
        sendClientCommand(player, 'TOC', 'ChangePlayerState', { toc_data.Limbs } )
    end


end

local function TocUpdateEveryTenMinutes()

    local player = getPlayer()

    if player == nil then
        return
    end
    local toc_data = player:getModData().TOC
    local part_data = toc_data.Limbs

    --Experience for prosthesis user
    for _, side in ipairs(TOC_sides) do
        if part_data[side .. "_Hand"].is_prosthesis_equipped or part_data[side .. "_LowerArm"].is_prosthesis_equipped then
            player:getXp():AddXP(Perks[side .. "_Hand"], 4)
        end

    end

    -- Updates the cicatrization time
    for _, part_name in pairs(GetBodyParts()) do
        if part_data[part_name].is_cut and not part_data[part_name].is_cicatrized then
            part_data[part_name].cicatrization_time = part_data[part_name].cicatrization_time - 1 -- TODO Make it more "dynamic"
        end
    end

end

Events.EveryTenMinutes.Add(TocUpdateEveryTenMinutes)
Events.EveryOneMinute.Add(TocUpdateEveryOneMinute)
