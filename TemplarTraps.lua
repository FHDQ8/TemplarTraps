local CreepBlocker = {}

CreepBlocker.creep_melee_collision_size = 16
CreepBlocker.key = Menu.AddKeyOption({"Utility"}, "[Bot] CreepBlock", Enum.ButtonCode.KEY_SPACE)
-- local enemyHeroBlock = Menu.AddOption({ "Utility", "[Bot] HeroBlock" }, "Enabled", "Block enemy hero with summoned units.")
CreepBlocker.skipRangedCreep = Menu.AddOption({ "Utility", "[Bot] Skip ranged creep" }, "Enabled", "Bot will try to skip ranged creep.")
CreepBlocker.font = Renderer.LoadFont("Elephant", 20, Enum.FontWeight.EXTRABOLD)

function CreepBlocker.OnGameStart()
    CreepBlocker.init()
end

function CreepBlocker.OnGameEnd()
    CreepBlocker.init()
end

function CreepBlocker.init()
    -- local npc_to_ignore = {}
    CreepBlocker.top_towers = {}
    CreepBlocker.mid_towers = {}
    CreepBlocker.bottom_towers = {}
    CreepBlocker.my_team = nil
    CreepBlocker.last_stop = 0
    CreepBlocker.sleep = 0
    CreepBlocker.time = 0
    CreepBlocker.less_stopping = false
    CreepBlocker.Fountain = nil
end

CreepBlocker.init()

function CreepBlocker.OnDraw()
    if not Menu.IsKeyDown(CreepBlocker.key) then
        return false
    end

    local myHero = Heroes.GetLocal()
    if not myHero then return end
    --if not CreepBlocker.Fountain or CreepBlocker.Fountain == nil then
       -- CreepBlocker.getFountain(myHero)
    --end
    local hero_collision_size = 24
    local radius = 500

    local creeps = NPC.GetUnitsInRadius(myHero, radius, Enum.TeamType.TEAM_FRIEND)
    local origin = Entity.GetAbsOrigin(myHero)

    local best_npc = nil
    local best_position = nil
    local best_distance = 99999
    local best_angle = 0.0

    local curtime = GameRules.GetGameTime()
    --local fountain_origin = Entity.GetAbsOrigin(Fountain)
    --local hero_to_fountain_len = (origin - fountain_origin):Length()

    local hx, hy = Renderer.WorldToScreen(origin)
    if CreepBlocker.less_stopping then
        Renderer.SetDrawColor(255, 0, 0, 255)
        Renderer.DrawText(CreepBlocker.font, hx, hy, 'BOT IN LEARNING MODE', 1)
    end

    for i, npc in ipairs(creeps) do
        if NPC.IsCreep(npc) and not Entity.IsDormant(npc) and Entity.IsAlive(npc) then
            local npc_id = Entity.GetIndex(npc)
            local creep_origin = Entity.GetAbsOrigin(npc)

            local ranged = false
            if Menu.IsEnabled(CreepBlocker.skipRangedCreep) and NPC.IsRanged(npc) then
                ranged = true
            end

            local x, y = Renderer.WorldToScreen(creep_origin)
            CreepBlocker.DrawCircle(creep_origin, CreepBlocker.creep_melee_collision_size)

            local angle = math.atan(y - hy, x - hx)
            Renderer.SetDrawColor(255, 0, 0, 255)
            Renderer.DrawText(CreepBlocker.font, hx, hy, 'BOT IN LEARNING MODE', 1)

            local moves_to = CreepBlocker.GetPredictedPosition(npc, 0.66)

            if not NPC.IsRunning(npc) or ranged then
                -- do nothing here
            else
                local x2, y2 = Renderer.WorldToScreen(moves_to)
                Renderer.DrawLine(x, y, x2, y2)

                local distance = (origin - creep_origin):Length()
                distance = distance - hero_collision_size

                if distance <= best_distance then
                    --best_npc = npc
                    best_position = moves_to
                    best_distance = distance
                    --best_angle = angle
                end
            end
        end
    end

    if best_position then
        --local pos_to_fountain_len = (best_position - fountain_origin):Length()
        -- local name = NPC.GetUnitName(best_npc)

        if curtime > CreepBlocker.sleep then
            Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, myHero, best_position, nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY)
        end
        local dist = (best_position - origin):Length()
        local speed = CreepBlocker.GetMoveSpeed(myHero)

        if speed <= 500 and speed >= 400 then
            CreepBlocker.time = 0.15
        elseif speed <= 400 and speed >= 385 then
            CreepBlocker.time = 0.20
        elseif speed <= 385 and speed >= 375 then
            CreepBlocker.time = 0.25
        elseif speed <= 375 and speed >= 365 then
            CreepBlocker.time = 0.35
        elseif speed <= 365 and speed >= 355 then
            CreepBlocker.time = 0.40
        elseif speed <= 355 and speed >= 345 then
            CreepBlocker.time = 0.45
        elseif speed <= 345 and speed >= 335 then
            CreepBlocker.time = 0.50
        elseif speed <= 335 and speed >= 325 then
            CreepBlocker.time = 0.55
        elseif speed <= 325 and speed >= 315 then
            CreepBlocker.time = 0.65
        elseif speed <= 315 and speed >= 305 then
            CreepBlocker.time = 0.75
        elseif speed <= 305 and speed >= 295 then
            CreepBlocker.time = 0.85
        elseif speed <= 295 and speed >= 285 then
            CreepBlocker.time = 0.95
        elseif speed <= 285 and speed >= 275 then
            CreepBlocker.time = 1.00
        elseif speed <= 275 and speed >= 265 then
            CreepBlocker.time = 2.00
        end

        -- if curtime > last_stop and dist >= 15 * speed / 315 and dist <= 150 * speed / 315 then
        if curtime > CreepBlocker.last_stop and dist >= 10 and dist <= 150 then
            if CreepBlocker.less_stopping then
                CreepBlocker.last_stop = curtime + CreepBlocker.time * 315 / speed
            elseif not CreepBlocker.less_stopping then
                CreepBlocker.last_stop = curtime + CreepBlocker.time + 0.12 * 315 / speed
            end
            -- if speed < 315 then
            --     sleep = curtime + 0.05
            -- else
            --     sleep = curtime + 0.07
            -- end
            CreepBlocker.sleep = curtime + 22 / speed; --0.07 * 315 / speed;
            Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_STOP, myHero, best_position, nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY)
        end
    end

    -- get my line and towers
    --[[
    CreepBlocker.less_stopping = false;
    local TOWER_WARNING = 350;
    for i, tower in pairs(CreepBlocker.top_towers) do;
        local torigin = Entity.GetAbsOrigin(tower);
        if Entity.IsNPC(tower) and (origin - torigin):Length() <= TOWER_WARNING then;
            CreepBlocker.less_stopping = true;
        end;
    end;
    for i, tower in pairs(CreepBlocker.mid_towers) do;
        local torigin = Entity.GetAbsOrigin(tower);
        if Entity.IsNPC(tower) and (origin - torigin):Length() <= TOWER_WARNING then;
            CreepBlocker.less_stopping = true;
        end;
    end;
    for i, tower in pairs(CreepBlocker.bottom_towers) do;
        local torigin = Entity.GetAbsOrigin(tower);
        if Entity.IsNPC(tower) and (origin - torigin):Length() <= TOWER_WARNING then;
            CreepBlocker.less_stopping = true;
        end;
    end;
    ]]

end

-- return predicted position
function CreepBlocker.GetPredictedPosition(npc, delay)
    local pos = Entity.GetAbsOrigin(npc)
    if not NPC.IsRunning(npc) or not delay then return pos end
    local totalLatency = (NetChannel.GetAvgLatency(Enum.Flow.FLOW_INCOMING) + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING)) -- * 2 -- this may fix bot is not stopping at high ping
    delay = delay + totalLatency

    local dir = Entity.GetRotation(npc):GetForward():Normalized()
    local speed = CreepBlocker.GetMoveSpeed(npc)

    return pos + dir:Scaled(speed * delay)
end

function CreepBlocker.GetMoveSpeed(npc)
    local base_speed = NPC.GetBaseSpeed(npc)
    local bonus_speed = NPC.GetMoveSpeed(npc) - NPC.GetBaseSpeed(npc)

    return base_speed + bonus_speed
end

local size_x, size_y = Renderer.GetScreenSize()

function CreepBlocker.DrawCircle(UnitPos, radius)
    local x1, y1 = Renderer.WorldToScreen(UnitPos)
    if x1 < size_x and x1 > 0 and y1 < size_y and y1 > 0 then
        local x4, y4, x3, y3, visible3
        local dergee = 90
        for angle = 0, 360 / dergee do
            x4 = 0 * math.cos(angle * dergee / 57.3) - radius * math.sin(angle * dergee / 57.3)
            y4 = radius * math.cos(angle * dergee / 57.3) + 0 * math.sin(angle * dergee / 57.3)
            x3,y3 = Renderer.WorldToScreen(UnitPos + Vector(x4,y4,0))
            Renderer.DrawLine(x1,y1,x3,y3)
            x1,y1 = Renderer.WorldToScreen(UnitPos + Vector(x4,y4,0))
        end
    end
end

function CreepBlocker.getFountain(Hero)

    local team = 'badguys'
    CreepBlocker.my_team = Entity.GetTeamNum(Hero)
    if CreepBlocker.my_team ~= 3 then
        team = 'goodguys'
    end

    for i = 1, NPCs.Count() do
        local npc = NPCs.Get(i)
        if NPC.IsStructure(npc) then
            local name = NPC.GetUnitName(npc)
            if name ~= nil then

                if name == "dota_fountain" then
                    if Entity.IsSameTeam(Hero, npc) then
                        Fountain = npc
                    -- else
                    -- Blocker.EnemyFountain = npc
                    end
                end

                if name == "npc_dota_"..team.."_tower1_top" then
                    CreepBlocker.top_towers[1] = npc
                end
                if name == "npc_dota_"..team.."_tower2_top" then
                    CreepBlocker.top_towers[2] = npc
                end
                if name == "npc_dota_"..team.."_tower3_top" then
                    CreepBlocker.top_towers[3] = npc
                end

                if name == "npc_dota_"..team.."_tower1_mid" then
                    CreepBlocker.mid_towers[1] = npc
                end
                if name == "npc_dota_"..team.."_tower2_mid" then
                    CreepBlocker.mid_towers[2] = npc
                end
                if name == "npc_dota_"..team.."_tower3_mid" then
                    CreepBlocker.mid_towers[3] = npc
                end

                if name == "npc_dota_"..team.."_tower1_bot" then
                    CreepBlocker.bottom_towers[1] = npc
                end
                if name == "npc_dota_"..team.."_tower2_bot" then
                    CreepBlocker.bottom_towers[2] = npc
                end
                if name == "npc_dota_"..team.."_tower3_bot" then
                    CreepBlocker.bottom_towers[3] = npc
                end

            end
        end
    end
end

return CreepBlocker
