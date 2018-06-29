local TemplarTraps = {}

TemplarTraps.Enabled = Menu.AddOption({"Hero Specific", "Templar Assassin", "TemplarTraps"}, "{1} Enabled", "v0.1")
TemplarTraps.UseTraps = Menu.AddOption({"Hero Specific", "Templar Assassin", "TemplarTraps"}, "{2} Auto Use Traps", "")
TemplarTraps.DrawRange = Menu.AddOption({"Hero Specific", "Templar Assassin", "TemplarTraps"}, "{3} Draw a range of traps", "")
TemplarTraps.DropAeon = Menu.AddOption({"Hero Specific", "Templar Assassin", "TemplarTraps"}, "{4} Drop aeon", "")
TemplarTraps.ActiveClosest = Menu.AddOption({"Hero Specific", "Templar Assassin", "TemplarTraps"}, "{5} Activation the trap closest to the cursor", "")
TemplarTraps.FontSize = Menu.AddOption({"Hero Specific", "Templar Assassin", "TemplarTraps"}, "{6} Font size", "", 15, 30, 1)

TemplarTraps.Font = nil

function TemplarTraps.OnScriptLoad()
	TemplarTraps.Font = Renderer.LoadFont("Tahoma", Menu.GetValue(TemplarTraps.FontSize), Enum.FontWeight.EXTRABOLD)
end

local particle_list = {}
function TemplarTraps.OnMenuOptionChange(option, oldValue, newValue)
	if option == TemplarTraps.DrawRange then
		if newValue == 0 then
			for i, v in pairs(particle_list) do
				Particle.Destroy(v)
			end
			particle_list = {}
		end
	elseif option == TemplarTraps.FontSize then
		TemplarTraps.Font = Renderer.LoadFont("Tahoma", newValue, Enum.FontWeight.EXTRABOLD)
	end
end

local wisp_overcharge = 1
local kunkka_ghostship = 1
local flame_guard = 0
function TemplarTraps.GetDamageAndShieldAfterDetonate(hero_state, remote_damage, delay)
	local Unit = hero_state.npc
	local UnitPos = hero_state.pos
	local time_past
	if delay then
		if hero_state.last_delay then
			time_past = delay - hero_state.last_delay
		else
			time_past = delay
		end
	end
	if not UnitPos then
		UnitPos = Entity.GetAbsOrigin(Unit)
	end
	local Hp = hero_state.hp
	if not Hp then
		Hp = Entity.GetHealth(Unit)
	end
	local HpMax = hero_state.hpmax
	if not HpMax then
		HpMax = Entity.GetMaxHealth(Unit)
	end
	if time_past and Hp ~= HpMax then
		Hp = Hp + NPC.GetHealthRegen(Unit) * time_past
	end
	local Mp = hero_state.mp
	if not Mp then
		Mp = (NPC.GetMana(Unit) + NPC.GetManaRegen(Unit) * 5)
	end
	local Shield = hero_state.shield
	local visage_stack = hero_state.visage_stack
	local templar_stack = hero_state.templar_stack
	local additional_res = 1
	local base_resist = NPC.GetMagicalArmorDamageMultiplier(Unit)

	if not Shield then
		Shield = 0
		if NPC.HasModifier(Unit, "modifier_item_hood_of_defiance_barrier") then
			Shield = Shield + 325
		end
		if NPC.HasModifier(Unit, "modifier_item_pipe_barrier") then
			Shield = Shield + 400
		end
		if NPC.HasItem(Unit, "item_infused_raindrop", 1) and Ability.GetCooldownTimeLeft(NPC.GetItem(Unit, "item_infused_raindrop", 1)) == 0 then
			remote_damage = remote_damage - 120
			if remote_damage < 0 then
				remote_damage = 0
			end
		end
		if NPC.HasModifier(Unit, "modifier_ember_spirit_flame_guard") then
			Shield = Shield + flame_guard
		end
	end

	if NPC.HasAbility(Unit, "spectre_dispersion") then -- damage_reflection_pct
		additional_res = additional_res * (1 - Ability.GetLevelSpecialValueFor(NPC.GetAbility(Unit, "spectre_dispersion"), "damage_reflection_pct") / 100)
	end

	if NPC.HasAbility(Unit, "antimage_spell_shield") and Entity.IsDormant(Unit) then -- spell_shield_resistance
		additional_res = additional_res * (1 - Ability.GetLevelSpecialValueFor(NPC.GetAbility(Unit, "antimage_spell_shield"), "spell_shield_resistance") / 100)
	end

	if NPC.HasItem(Unit, "item_cloak", 1) and Entity.IsDormant(Unit) then -- spell_shield_resistance
		additional_res = additional_res * 0.85
	end

	if NPC.HasItem(Unit, "item_hood_of_defiance", 1) and Entity.IsDormant(Unit) then -- spell_shield_resistance
		additional_res = additional_res * 0.75
	end

	if NPC.HasItem(Unit, "item_pipe", 1) and Entity.IsDormant(Unit) then -- spell_shield_resistance
		additional_res = additional_res * 0.70 * 0.9 -- aura
	end

	if NPC.HasModifier(Unit, "modifier_wisp_overcharge") then
		additional_res = additional_res * wisp_overcharge
	end

	if NPC.HasModifier(Unit, "modifier_kunkka_ghost_ship_damage_absorb") then
		additional_res = additional_res * kunkka_ghostship
	end

	if NPC.HasModifier(Unit, "modifier_ursa_enrage") then
		additional_res = additional_res * 0.2
	end

	if NPC.HasModifier(Unit, "modifier_pangolier_shield_crash_buff") then
		additional_res = additional_res * (1 - Modifier.GetStackCount(NPC.GetModifier(Unit, "modifier_pangolier_shield_crash_buff")) / 100)
	end

	if NPC.HasModifier(Unit, "modifier_visage_gravekeepers_cloak") then -- damage_reduction
		if not visage_stack then
			visage_stack = Modifier.GetStackCount(NPC.GetModifier(Unit, "modifier_visage_gravekeepers_cloak"))
		end
		if visage_stack > 0 then
			local resist = (1 - Ability.GetLevelSpecialValueFor(NPC.GetAbility(Unit, "visage_gravekeepers_cloak"), "damage_reduction") / 100 * visage_stack)
			visage_stack = visage_stack - 1
			additional_res = additional_res * resist
		end
	end

	if NPC.HasModifier(Unit, "modifier_templar_assassin_refraction_absorb") then
		if not templar_stack then
			templar_stack = Modifier.GetStackCount(NPC.GetModifier(Unit, "modifier_templar_assassin_refraction_absorb"))
		end
		if templar_stack > 0 then
			templar_stack = templar_stack - 1
			additional_res = 0
		end
	end

	if NPC.HasModifier(Unit, "modifier_medusa_mana_shield") then -- absorption_tooltip
		local resist = 1 - Ability.GetLevelSpecialValueFor(NPC.GetAbility(Unit, "medusa_mana_shield"), "absorption_tooltip") / 100
		local damage_per_mana = Ability.GetLevelSpecialValueForFloat(NPC.GetAbility(Unit, "medusa_mana_shield"), "damage_per_mana")
		local mana_damage = remote_damage * (1 - resist) / damage_per_mana
		if Mp >= mana_damage then
			Mp = Mp - mana_damage
		else
			resist = (remote_damage * resist + (mana_damage - Mp) * damage_per_mana) / remote_damage
			Mp = 0
		end
		additional_res = additional_res * resist
	end

	if NPC.HasAbility(Unit, "huskar_berserkers_blood") then -- maximum_resistance
		local resist = (1 - (Hp - Entity.GetMaxHealth(Unit) * 0.1) / (Entity.GetMaxHealth(Unit) * 0.9)) * (Ability.GetLevelSpecialValueFor(NPC.GetAbility(Unit, "huskar_berserkers_blood"), "maximum_resistance") / 100)
		if resist > Ability.GetLevelSpecialValueFor(NPC.GetAbility(Unit, "huskar_berserkers_blood"), "maximum_resistance") / 100 then
			resist = Ability.GetLevelSpecialValueFor(NPC.GetAbility(Unit, "huskar_berserkers_blood"), "maximum_resistance") / 100
		end
		base_resist = base_resist / (1 - (1 - (Entity.GetHealth(Unit) - Entity.GetMaxHealth(Unit) * 0.1) / (Entity.GetMaxHealth(Unit) * 0.9)) * (Ability.GetLevelSpecialValueFor(NPC.GetAbility(Unit, "huskar_berserkers_blood"), "maximum_resistance") / 100))
		additional_res = additional_res * (1 - resist)
	end

	local calc_remote_damage = (remote_damage - Shield) * base_resist * additional_res
	if calc_remote_damage < 0 then
		calc_remote_damage = 0
	end
	if NPC.HasItem(Unit, "item_aeon_disk", 1) and Ability.GetCooldownTimeLeft(NPC.GetItem(Unit, "item_aeon_disk", 1)) == 0 and (Hp - calc_remote_damage) / Entity.GetMaxHealth(Unit) < 0.7 then -- spell_shield_resistance
		if Menu.IsEnabled(TemplarTraps.DropAeon) then
			Hp = 0
			calc_remote_damage = 999999
		else
			additional_res = 0
		end
	end
	Hp = Hp - (remote_damage - Shield) * base_resist * additional_res
	if Shield - remote_damage > 0 then
		Shield = Shield - remote_damage
	else
		Shield = 0
	end
	return {npc = Unit, last_delay = delay, hp = Hp, hpmax = HpMax, mp = Mp, shield = Shield, visage_stack = visage_stack, templar_stack = templar_stack}, calc_remote_damage
end

local last_check = 0
function TemplarTraps.OnGameStart()
	last_check = 0
end

function TemplarTraps.OnDraw()
	
	if not Menu.IsEnabled(TemplarTraps.Enabled) then return end

	local myHero = Heroes.GetLocal()
	
	if not myHero then
		return
	end
	
	if NPC.GetUnitName(myHero) ~= "npc_dota_hero_templar_assassin" then
		return
	end
	
	local magicalDamageMul = 1 + Hero.GetIntellectTotal(myHero)/ 14 / 100 + 0.1 *(NPC.HasItem(myHero, "item_kaya", 1) and 1 or 0)
	local trap = NPC.GetAbility(myHero, "templar_assassin_psionic_trap")
	local trap_damage = (Ability.GetLevelSpecialValueFor(trap, "trap_bonus_damage") + Ability.GetLevel(NPC.GetAbilityByIndex(myHero, 9)) * 200) * magicalDamageMul
	local trap_damage_time = Ability.GetLevelSpecialValueFor(trap, "trap_duration_tooltip")
	
	for i, Unit in pairs(NPCs.GetAll()) do
	
		if NPC.HasAbility(Unit, "wisp_overcharge") then -- bonus_damage_pct
			wisp_overcharge = 1 + Ability.GetLevelSpecialValueFor(NPC.GetAbility(Unit, "wisp_overcharge"), "bonus_damage_pct") / 100
		end
		if NPC.HasAbility(Unit, "kunkka_ghostship") then -- ghostship_absorb
			kunkka_ghostship = 1 - Ability.GetLevelSpecialValueFor(NPC.GetAbility(Unit, "kunkka_ghostship"), "ghostship_absorb") / 100
		end
		if NPC.HasAbility(Unit, "ember_spirit_flame_guard") then -- absorb_amount
			flame_guard = Ability.GetLevelSpecialValueFor(NPC.GetAbility(Unit, "ember_spirit_flame_guard"), "absorb_amount")
		end
		
		local name = NPC.GetUnitName(Unit)
		if name and name == "npc_dota_templar_assassin_psionic_trap" then
			if not particle_list[Unit] and Menu.IsEnabled(TemplarTraps.DrawRange) then
				particle_list[Unit] = Particle.Create("particles\\ui_mouseactions\\drag_selected_ring.vpcf")
				Particle.SetControlPoint(particle_list[Unit], 0, Entity.GetAbsOrigin(Unit))
				Particle.SetControlPoint(particle_list[Unit], 1, Vector(190, 128, 190))
				Particle.SetControlPoint(particle_list[Unit], 2, Vector(450, 255, 0))
				Particle.SetControlPoint(particle_list[Unit], 3, Vector(20, 0, 0))
			end
			if Entity.IsSameTeam(myHero, Unit) and Menu.IsEnabled(TemplarTraps.UseTraps) then
				local modif = NPC.GetModifier(Unit, "modifier_templar_assassin_trap")
				if Entity.GetOwner(Unit) == myHero and modif then
					local x, y, visible = Renderer.WorldToScreen(Entity.GetAbsOrigin(Unit))
					if Entity.GetOwner(Unit) == myHero then
						local life_time = GameRules.GetGameTime() - Modifier.GetCreationTime(modif)
						local power = life_time > 4.1 and 1 or (life_time / 4.1)
						if visible == 1 and life_time < 4 then
							Renderer.SetDrawColor(255, 255, 255, 255)
							Renderer.DrawText(TemplarTraps.Font, x, y, math.floor((4 - life_time) * 100) / 100)
						end
						if power == 1 then
							for j, hero in pairs(Entity.GetHeroesInRadius(Unit, 375, Enum.TeamType.TEAM_ENEMY)) do
								local x, y = Renderer.WorldToScreen(Entity.GetAbsOrigin(hero))
								local hero_state = {npc = hero}
								
								local trap_damage_time = trap_damage_time + 0.04
								if NPC.HasItem(hero, "item_aeon_disk", 1) then
									trap_damage_time = trap_damage_time * ((NPC.HasItem(hero, "item_aeon_disk", 1) and 1 or 0) * 0.75)
								end
								Renderer.SetDrawColor(255, 255, 255, 255)
								for i = 1.04, trap_damage_time do
									hero_state = TemplarTraps.GetDamageAndShieldAfterDetonate(hero_state, math.floor(trap_damage / trap_damage_time), i - 1)
									--Renderer.DrawText(TemplarTraps.Font, x, y + 20 * math.ceil(i), math.floor(hero_state.hp * 100) / 100)
								end
								
								Renderer.DrawText(TemplarTraps.Font, x, y, math.floor(hero_state.hp * 100) / 100)
								
								if math.floor(hero_state.hp) < 0 and not NPC.HasModifier(hero, "modifier_templar_assassin_trap_slow") and GameRules.GetGameTime() - last_check > 0.1 then
									last_check = GameRules.GetGameTime()
									Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, 0, Vector(0, 0, 0), NPC.GetAbilityByIndex(Unit, 0), Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, Unit, 0, 0)
								end
							end
						end
					end
				end
			elseif Entity.IsAlive(Unit) and Menu.IsEnabled(TemplarTraps.UseTraps) then
				local x, y, visible = Renderer.WorldToScreen(Entity.GetAbsOrigin(Unit))
				if visible == 1 then
					Renderer.SetDrawColor(255, 255, 255, 255)
					Renderer.DrawText(TemplarTraps.Font, x, y, "enemy trap")
				end
			end
			if particle_list[Unit] and not Entity.IsAlive(Unit) then
				Particle.Destroy(particle_list[Unit])
				particle_list[Unit] = nil
			end
		end
	end
end

function TemplarTraps.OnPrepareUnitOrders(orders)
	if not Menu.IsEnabled(TemplarTraps.Enabled) or not Menu.IsEnabled(TemplarTraps.ActiveClosest) then return true end

	local myHero = Heroes.GetLocal()
	
	if not myHero then
		return true
	end
	
	if NPC.GetUnitName(myHero) ~= "npc_dota_hero_templar_assassin" then
		return true
	end

	if orders.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET and orders.ability and Ability.GetName(orders.ability) == "templar_assassin_trap" then
		local pos = Input.GetWorldCursorPos()
		local closest_trap, dist
		for i, Unit in pairs(NPCs.GetAll()) do
			local modif = NPC.GetModifier(Unit, "modifier_templar_assassin_trap")
			local UnitPos = Entity.GetAbsOrigin(Unit)
			if Entity.GetOwner(Unit) == myHero and modif then
				if not dist or dist > (UnitPos - pos):Length2DSqr() then
					closest_trap = Unit
					dist = (UnitPos - pos):Length2DSqr()
				end
			end
		end
		if closest_trap then
			Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, 0, Vector(0, 0, 0), NPC.GetAbilityByIndex(closest_trap, 0), Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, closest_trap, 0, 0)
		end
		return false
	end

	return true
end

return TemplarTraps