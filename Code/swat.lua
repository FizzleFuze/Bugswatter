--Copyright
--[[
*******************************************************************************
Fizzle_Fuze's Surviving Mars Mods
Copyright (c) 2022 Fizzle Fuze Enterprises (mods@fizzlefuze.com)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

  If your software can interact with users remotely through a computer
network, you should also make sure that it provides a way for users to
get its source.  For example, if your program is a web application, its
interface could display a "Source" link that leads users to an archive
of the code.  There are many ways you could offer source, and different
solutions will be better for different programs; see section 13 for the
specific requirements.

  You should also get your employer (if you work as a programmer) or school,
if any, to sign a "copyright disclaimer" for the program, if necessary.
For more information on this, and how to apply and follow the GNU AGPL, see
<https://www.gnu.org/licenses/>.
*******************************************************************************
--]]

--mod name
local ModName = "["..CurrentModDef.title.."]"

--logging variables
local Debugging, Info = false, false

--print log messages to console and disk
local function PrintLog()
    local MsgLog = SharedModEnv["Fizzle_FuzeLog"]

    if #MsgLog > 0 then
        --print logged messages to console and file
        for _, Msg in ipairs(MsgLog) do
            print(Msg)
        end
        FlushLogFile()

        --reset
        SharedModEnv["Fizzle_FuzeLog"] = {}
        return
    end
end

--setup cross-mod variables for log if needed
if not SharedModEnv["Fizzle_FuzeLog"] then
    SharedModEnv["Fizzle_FuzeLog"] = { ModName.." INFO: First Fizzle_Fuze mod loading!" }
end

--main logging function
function Fizzle_FuzeLogMessage(...)
    local Sev, Arg = nil, {...}
    local SevType = {"INFO", "DEBUG", "WARNING", "ERROR", "CRITICAL"}

    if #Arg == 0 then
        print(ModName,"/?.lua CRITICAL: No error message!")
        FlushLogFile()
        MsgLog[#MsgLog+1] = ModName.."/?.lua CRITICAL: No error message!"
        SharedModEnv["Fizzle_FuzeLog"] = MsgLog
        return
    end

    for _, ST in ipairs(SevType) do
        if Arg[2] == ST then --2nd arg = severity
            Arg[2] = Arg[2]..": " -- oh purty
            Sev = Arg[2]
            break
        end
    end

    if not Sev then
        Sev = "DEBUG: "
        Arg[2] = "DEBUG: "..Arg[2]
    end

    if (Sev == "DEBUG: " and Debugging == false) or (Sev == "INFO: " and Info == false) then
        return
    end

    local MsgLog = SharedModEnv["Fizzle_FuzeLog"]
    local Msg = ModName.."/"..Arg[1]..".lua "
    for i = 2, #Arg do
        Msg = Msg..tostring(Arg[i])
    end
    MsgLog[#MsgLog+1] = Msg
    SharedModEnv["Fizzle_FuzeLog"] = MsgLog

    if (Debugging == true or Info == true) and Sev == "WARNING" or Sev == "ERROR" or Sev == "CRITICAL" then
        PrintLog()
    end
end

--wrapper logging function for this file
local function Log(...)
    Fizzle_FuzeLogMessage("swat", ...)
end

--fix for incorrect work performance penalty when training in home dome
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

--event handling
function OnMsg.NewHour()
    if Debugging == true then
        Log("New Hour!")
        PrintLog()
    end
end

--event handling
function OnMsg.NewDay()
    --log errors every day when not debugging
    PrintLog()
end