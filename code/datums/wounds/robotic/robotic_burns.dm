/datum/wound_pregen_data/burnt_metal
	abstract = TRUE

	required_limb_biostate = BIO_METAL

/datum/wound/burn/robotic/overheat
	treat_text = "Introduction of a cold environment or lowering of body temperature."

	/// The virtual temperature of the chassis. Crucial for many things, like our severity, the temp we transfer, our cooling damage, etc.
	var/chassis_temperature

	/// The lower bound of the chassis_temperature we can start with.
	var/starting_temperature_min = (BODYTEMP_NORMAL + 200)
	/// The upper bound of the chassis_temperature we can start with.
	var/starting_temperature_max = (BODYTEMP_NORMAL + 250)

	/// If [chassis_temperature] goes below this, we reduce in severity.
	var/cooling_threshold = (BODYTEMP_NORMAL + 3)
	/// If [chassis_temperature] goes above this, we increase in severity.
	var/heating_threshold = (BODYTEMP_NORMAL + 300)

	/// The buffer in kelvin we will subtract from the chassis_temperature of a wound we demote to.
	var/cooling_demote_buffer = 60
	/// The buffer in kelvin we will add to the chassis_temperature of a wound we promote to.
	var/heating_promote_buffer = 60

	/// The coefficient of heat transfer we will use when shifting our temp to the victim's.
	var/bodytemp_coeff = 0.04
	/// The coefficient of heat transfer we will use when shifting our victim's temp to ours.
	var/outgoing_bodytemp_coeff = 0
	/// The mult applied to heat output when we are on a important limb, e.g. head/torso.
	var/important_outgoing_mult = 1.2
	/// The coefficient of heat transfer we will use when shifting our temp to a turf.
	var/turf_coeff = 0.02

	/// If we are hit with burn damage, the damage will be multiplied against this to determine the effective heat we get.
	var/incoming_damage_heat_coeff = 3

	/// The coefficient of heat transfer we will use when receiving heat from reagent contact.
	var/base_reagent_temp_coefficient = 0.07

	/// The ratio of temp shift -> brute damage. Careful with this value, it can make stuff really really nasty.
	var/heat_shock_delta_to_damage_ratio = 0.2
	/// The minimum heat difference we must have on reagent contact to cause heat shock damage.
	var/heat_shock_minimum_delta = 5

	/// The max temp differential we can have applied to our limb during this tick interval, used for preventing things like splashing a beaker to instantly kill someone.
	var/reagent_temp_diff_allowed_this_interval = 0
	/// The max temp differential we can have applied to our limb during a given tick interval, used for preventing things like splashing a beaker to instantly kill someone.
	var/reagent_temp_diff_allowed_per_interval = 70

	/// The wound we demote to when we go below cooling threshold. If null, removes us.
	var/datum/wound/burn/robotic/demotes_to
	/// The wound we promote to when we go above heating threshold.
	var/datum/wound/burn/robotic/promotes_to

	/// The color of the light we will generate.
	var/light_color
	/// The power of the light we will generate.
	var/light_power
	/// The range of the light we will generate.
	var/light_range

	/// The glow we have attached to our victim, to simulate our limb glowing.
	var/obj/effect/dummy/lighting_obj/moblight/mob_glow

	wound_series = WOUND_SERIES_METAL_BURN_OVERHEAT
	scar_file = ROBOTIC_METAL_BURN_SCAR_FILE

	processes = TRUE

/datum/wound/burn/robotic/overheat/New(temperature)
	chassis_temperature = temperature
	if (isnull(temperature))
		chassis_temperature = get_random_starting_temperature()
	else
		chassis_temperature = temperature

	return ..()

/datum/wound/burn/robotic/overheat/Destroy()
	. = ..()

	if (mob_glow)
		QDEL_NULL(mob_glow)

/datum/wound/burn/robotic/overheat/set_victim(mob/living/new_victim)
	if (victim)
		//glow.loc = limb
		//glow.update_light()
		qdel(mob_glow)
		UnregisterSignal(victim, COMSIG_MOB_AFTER_APPLY_DAMAGE)
		UnregisterSignal(victim, COMSIG_ATOM_AFTER_EXPOSE_REAGENTS)
	if (new_victim)
		//glow.loc = new_victim
		//glow.update_light()
		mob_glow = new_victim.mob_light(light_range, light_power, light_color)
		mob_glow.set_light_on(TRUE)
		RegisterSignal(new_victim, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(victim_attacked))
		RegisterSignal(new_victim, COMSIG_ATOM_AFTER_EXPOSE_REAGENTS, PROC_REF(victim_exposed_to_reagents))

	return ..()

/datum/wound/burn/robotic/overheat/proc/get_random_starting_temperature()
	return LERP(starting_temperature_min, starting_temperature_max, rand())

/datum/wound/burn/robotic/overheat/proc/generate_initial_glow(obj/item/bodypart/limb)
	RETURN_TYPE(/obj/effect/dummy/lighting_obj)

	return new /obj/effect/dummy/lighting_obj(limb, light_range, light_power, light_color)

/datum/wound/burn/robotic/get_limb_examine_description()
	return span_warning("The metal on this limb is glowing radiantly.")

/datum/wound/burn/robotic/overheat/handle_process(seconds_per_tick, times_fired)

	reagent_temp_diff_allowed_this_interval = (reagent_temp_diff_allowed_per_interval * seconds_per_tick)

	if (victim)
		if (expose_temperature(victim.bodytemperature, (bodytemp_coeff * seconds_per_tick)))
			return
		if (outgoing_bodytemp_coeff)
			var/mult = outgoing_bodytemp_coeff
			if (!limb_unimportant())
				mult *= important_outgoing_mult
			victim.adjust_bodytemperature(((chassis_temperature - victim.bodytemperature) * mult) * TEMPERATURE_DAMAGE_COEFFICIENT * seconds_per_tick)
	else
		var/turf/our_turf = get_turf(limb)
		if (our_turf)
			expose_temperature(our_turf.GetTemperature(), (turf_coeff * seconds_per_tick))

/datum/wound/burn/robotic/overheat/proc/victim_attacked(datum/source, damage, damagetype, def_zone, blocked, wound_bonus, bare_wound_bonus, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER

	if (def_zone != limb.body_zone) // use this proc since receive damage can also be called for like, chems and shit
		return

	if (!victim)
		return

	if (damagetype != BURN)
		return

	if (wound_bonus == CANT_WOUND)
		return

	var/effective_damage = (damage - blocked)
	if (effective_damage <= 0)
		return

	expose_temperature((chassis_temperature + effective_damage), incoming_damage_heat_coeff)

/datum/wound/burn/robotic/overheat/proc/victim_exposed_to_reagents(datum/signal_source, list/reagents, datum/reagents/source, methods, volume_modifier, show_message)
	SIGNAL_HANDLER

	if (!(methods & TOUCH) && !(methods & VAPOR))
		return

	var/base_mult = 0
	if (methods & TOUCH)
		base_mult = 1
	else if (methods & VAPOR)
		base_mult = 0.05

	base_mult *= volume_modifier

	var/reagent_coefficient = (source.total_volume * base_reagent_temp_coefficient) * base_mult

	expose_temperature(source.chem_temp, reagent_coefficient, TRUE, TRUE) // if we are sprayed with something, we will immediately cool. or heat the fuck up :)

/datum/wound/burn/robotic/overheat/proc/expose_temperature(temperature, coeff = 0.02, heat_shock = FALSE, use_max = FALSE)
	var/temp_delta = (temperature - chassis_temperature) * coeff

	if (use_max)
		var/sign = SIGN(temp_delta)
		temp_delta = min(abs(temp_delta), reagent_temp_diff_allowed_this_interval)
		reagent_temp_diff_allowed_this_interval -= abs(temp_delta)
		temp_delta *= sign

	if(temp_delta > 0)
		chassis_temperature = min(chassis_temperature + max(temp_delta, 1), temperature)
	else
		chassis_temperature = max(chassis_temperature + min(temp_delta, -1), temperature)

	if (heat_shock && abs(temp_delta) > heat_shock_minimum_delta)
		if (victim)
			victim.visible_message(span_warning("[victim]'s [limb.plaintext_zone] strains from the thermal shock!"))
			playsound(victim, 'sound/items/welder.ogg', 25)
		limb.receive_damage(brute = (abs(temp_delta) * heat_shock_delta_to_damage_ratio), wound_bonus = CANT_WOUND)

	return check_temperature()

/datum/wound/burn/robotic/overheat/proc/check_temperature()
	if (chassis_temperature < cooling_threshold)
		if (demotes_to)
			victim.visible_message(span_green("[victim]'s [limb.plaintext_zone] turns a more pleasant thermal color as it cools down a little..."), span_green("Your [limb.plaintext_zone] seems to cool down a little!"))
			replace_wound(new demotes_to(cooling_threshold - cooling_demote_buffer))
			return TRUE
		else
			victim.visible_message(span_green("[victim]'s [limb.plaintext_zone] simmers gently as it returns to its usual colors!"), span_green("Your [limb.plaintext_zone] simmers gently as it returns to its usual colors!"))
			remove_wound()
			return TRUE
	else if (promotes_to && chassis_temperature >= heating_threshold)
		victim.visible_message(span_warning("[victim]'s [limb.plaintext_zone] brightens as it overheats further!"), span_userdanger("Your [limb.plaintext_zone] sizzles and brightens as it overheats further!"))
		replace_wound(new promotes_to(heating_threshold + heating_promote_buffer))
		return TRUE

/datum/wound/burn/robotic/overheat/get_scanner_description(mob/user)
	var/desc = ..()

	desc += " Its current temperature is [span_blue("[chassis_temperature]")]K, and needs to cool to [span_nicegreen("[cooling_threshold]")]K, but \
			will worsen if heated to [span_purple("[heating_threshold]")]K."

	return desc

/datum/wound/burn/robotic/overheat/moderate
	name = "Transient Overheating"
	desc = "External metals have exceeded lower-bound thermal limits, and as such, have lost some structural integrity, increasing damage taken, as well as the chance to \
			sustain unrelated wounds."
	occur_text = "lets out a slight groan as it turns a dull shade of thermal red"
	examine_desc = "is glowing a dull thermal red and giving off heat"
	treat_text = "Reduction of body temperature to expedite the passive heat dissipation - or, if thermal shock is to be risked, application of a fire extinguisher/shower."
	severity = WOUND_SEVERITY_MODERATE

	damage_mulitplier_penalty = 1.1 //1.1x damage taken

	a_or_from = "from"

	// easy to get
	threshold_minimum = 30
	threshold_penalty = 30

	status_effect_type = /datum/status_effect/wound/burn/robotic/moderate

	sound_volume = 20

	outgoing_bodytemp_coeff = 0.001

	base_reagent_temp_coefficient = 0.05
	heat_shock_delta_to_damage_ratio = 0.16

	promotes_to = /datum/wound/burn/robotic/overheat/severe

	light_color = COLOR_RED
	light_power = 0.1
	light_range = 0.5

	can_scar = FALSE

/datum/wound_pregen_data/burnt_metal/transient_overheat
	abstract = FALSE

	wound_path_to_generate = /datum/wound/burn/robotic/overheat/moderate

/datum/wound/burn/robotic/overheat/severe
	name = "Thermal Overload"
	desc = "Exterior plating has surpassed critical thermal levels, causing significant failure in structural integrity and overheating of internal systems."
	occur_text = "sizzles, the externals turning a dull shade of orange"
	examine_desc = "appears discolored and polychromatic, parts of it glowing a dull orange"
	treat_text = "Isolation from physical hazards, and accomodation of passive heat dissipation - active cooling may be used, but temperature differentials significantly \
				raise the risk of thermal shock."
	severity = WOUND_SEVERITY_SEVERE

	a_or_from = "from"

	threshold_minimum = 80
	threshold_penalty = 65

	status_effect_type = /datum/status_effect/wound/burn/robotic/severe

	damage_mulitplier_penalty = 1.3 // 1.3x damage taken

	starting_temperature_min = (BODYTEMP_NORMAL + 400)
	starting_temperature_max = (BODYTEMP_NORMAL + 500)

	heating_promote_buffer = 100

	cooling_threshold = (BODYTEMP_NORMAL + 300)
	heating_threshold = (BODYTEMP_NORMAL + 600)

	outgoing_bodytemp_coeff = 0.003
	bodytemp_coeff = 0.01

	base_reagent_temp_coefficient = 0.03
	heat_shock_delta_to_damage_ratio = 0.1

	demotes_to = /datum/wound/burn/robotic/overheat/moderate
	promotes_to = /datum/wound/burn/robotic/overheat/critical

	light_color = COLOR_BRIGHT_ORANGE
	light_power = 0.8
	light_range = 0.5

	scar_keyword = "robotic_burnsevere"

/datum/wound_pregen_data/burnt_metal/transient_overheat
	abstract = FALSE

	wound_path_to_generate = /datum/wound/burn/robotic/overheat/moderate

/datum/wound/burn/robotic/overheat/critical
	name = "Runaway Exothermy"
	desc = "Carapace is beyond melting point, causing catastrophic structural integrity failure as well as massively heating up the subject."
	occur_text = "turns a bright shade of radiant white as it sizzles and melts"
	examine_desc = "is a blinding shade of white, almost melting from the heat"
	treat_text = "Immediate confinement to cryogenics, as rapid overheating and physical vulnerability may occur. Active cooling is inadvised, \
				since the thermal shock may be lethal with such a temperature differential."
	severity = WOUND_SEVERITY_CRITICAL

	a_or_from = "from"

	sound_effect = 'sound/effects/wounds/sizzle2.ogg'

	threshold_minimum = 140
	threshold_penalty = 100

	status_effect_type = /datum/status_effect/wound/burn/robotic/critical

	damage_mulitplier_penalty = 1.6 //1.6x damage taken

	starting_temperature_min = (BODYTEMP_NORMAL + 700)
	starting_temperature_max = (BODYTEMP_NORMAL + 900)

	cooling_demote_buffer = 100

	cooling_threshold = (BODYTEMP_NORMAL + 600)
	heating_threshold = INFINITY

	outgoing_bodytemp_coeff = 0.006 // burn... BURN...
	bodytemp_coeff = 0.008

	base_reagent_temp_coefficient = 0.008
	heat_shock_delta_to_damage_ratio = 0.07

	demotes_to = /datum/wound/burn/robotic/overheat/severe

	wound_flags = (MANGLES_FLESH)

	light_color = COLOR_VERY_SOFT_YELLOW
	light_power = 1.3
	light_range = 1.5

	scar_keyword = "robotic_burncritical"

/datum/wound_pregen_data/burnt_metal/severe
	abstract = FALSE

	wound_path_to_generate = /datum/wound/burn/robotic/overheat/severe

/datum/wound_pregen_data/burnt_metal/critical
	abstract = FALSE

	wound_path_to_generate = /datum/wound/burn/robotic/overheat/critical
