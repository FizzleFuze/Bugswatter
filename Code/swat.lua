--see Info/LICENSE for license and copyright info

local function Log(...)
    FF.Funcs.LogMessage("swat", ...)
end

--fix for incorrect work performance penalty when training in home dome

-- removed due to paradox fix
--[[
local ChangeWorkplacePerformance = Colonist.ChangeWorkplacePerformance
function Colonist:ChangeWorkplacePerformance ()
    ChangeWorkplacePerformance(self)

    local workplace = self.workplace
    if workplace then
        if self.dome == workplace.parent_dome and workplace.dome_label == "TrainingBuilding" then
            self:SetModifier("performance", "home_dome", 0, 0, "<green>Home dome bugfix: <amount></color>")
        end
    end

end
--]]

--Fix Story Bits Trigger: try every category, not just the first one that RNG selects
local StoryBitTriggerOrig = StoryBitTrigger
function StoryBitTrigger(msg, map_id, object)
    StoryBitTriggerOrig(msg, map_id, object)

    local states = g_StoryBitCategoryStates[msg]
    if states == nil then
        Log("[" .. StoryBitFormatGameTime() .. "]", " Trigger ", msg, "- no active story bits with this trigger!")
        return
    end

    local class = object and object.class or ""
    local random = AsyncRand(100)
    Log("[" .. StoryBitFormatGameTime() .. "]", " Trigger", msg, class, " on ", map_id)
    for category_name, category in pairs(states) do
        if category_name ~= "FollowUp" and category:CheckPrerequisites(map_id, object) then

            local category_preset = StoryBitCategories[category_name]
            local chance = category_preset and category_preset.Chance or 0
            if random < chance then
                if StoryBitGetGameTime() < category.cooldown_end then
                    Log("Category ", category.id, " rejected due to cooldown")
                elseif msg == "StoryBitTick" and 0 <= #category.storybit_states then
                    local sleep_time = const.StoryBits.TickDuration / 10 / #category.storybit_states
                    CreateGameTimeThread(function()
                        category:TryActivateStoryBit(map_id, object, Clamp(sleep_time, 1, 10))
                    end)
                else
                    if category:TryActivateStoryBit(map_id, object) == true then
                        break
                    end
                end
            end

            random = random - chance
        end
    end
end