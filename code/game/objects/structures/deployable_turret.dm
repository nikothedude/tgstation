/// DEPLOYABLE TURRET (FORMERLY MANNED TURRET)
//All of this file is five year old shitcode, and I'm too scared to touch more than I have to

/obj/machinery/deployable_turret
	name = "machine gun turret"
	desc = "While the trigger is held down, this gun will redistribute recoil to allow its user to easily shift targets."
	icon = 'icons/obj/weapons/turrets.dmi'
	icon_state = "machinegun"
	can_buckle = TRUE
	anchored = FALSE
	density = TRUE
	max_integrity = 100
	buckle_lying = 0
	layer = ABOVE_MOB_LAYER
	plane = GAME_PLANE_UPPER
	var/view_range = 2.5
	var/cooldown = 0

	var/obj/item/gun/mounted_gun
	var/gun_built_in = TRUE
	/// How long it takes for the gun to allow firing after a burst
	var/cooldown_duration = 9 SECONDS
	var/atom/target
	var/turf/target_turf
	var/warned = FALSE
	var/list/calculated_projectile_vars
	/// Sound to play at the end of a burst
	var/overheatsound = 'sound/weapons/sear.ogg'
	/// If using a wrench on the turret will start undeploying it
	var/can_be_undeployed = FALSE
	/// What gets spawned if the object is undeployed
	var/obj/spawned_on_undeploy
	/// How long it takes for a wrench user to undeploy the object
	var/undeploy_time = 3 SECONDS
	/// If TRUE, the turret will not become unanchored when not mounted
	var/always_anchored = FALSE

	var/fire_rate_mult = 1
	var/damage_mult = 1
	var/recoil_mult = 1

	var/list/obj/item/gun/accepted_types = list(
		/obj/item/gun/ballistic/automatic,
		/obj/item/gun/ballistic/shotgun,
		/obj/item/gun/ballistic/revolver,
		/obj/item/gun/ballistic/shotgun,
		/obj/item/gun/ballistic/rocketlauncher
	)

/obj/machinery/deployable_turret/Initialize(mapload)
	. = ..()
	if(always_anchored)
		set_anchored(TRUE)
	if (ispath(mounted_gun))
		var/obj/item/gun/new_gun = new mounted_gun(src)
		mounted_gun = null
		set_mounted_gun(new_gun)

/obj/machinery/deployable_turret/Destroy()
	if (gun_removable())
		remove_gun()
	else
		QDEL_NULL(mounted_gun)

	target = null
	target_turf = null
	return ..()

/obj/machinery/deployable_turret/examine(mob/user)
	. = ..()

	if (!isnull(mounted_gun))
		. += span_notice("It seems to have <b>[mounted_gun]</b> mounted onto it.")

/obj/machinery/deployable_turret/proc/gun_removable(mob/living/user)
	if (isnull(mounted_gun))
		return FALSE
	if (gun_built_in)
		return FALSE
	return TRUE

/obj/machinery/deployable_turret/proc/remove_gun(mob/living/user)
	if (!gun_removable(user))
		balloon_alert(user, "cant remove the gun!")
		return FALSE
	balloon_alert(user, "[mounted_gun] removed")
	if (iscarbon(user))
		var/mob/living/carbon/carbon_user = user
		INVOKE_ASYNC(carbon_user, TYPE_PROC_REF(/mob/living/carbon, put_in_hands), mounted_gun)
	else
		mounted_gun.forceMove(loc)

	set_mounted_gun(null)

/obj/machinery/deployable_turret/proc/set_mounted_gun(obj/item/gun/new_gun)
	if (mounted_gun == new_gun)
		return FALSE

	unmodify_mounted_gun()
	mounted_gun = new_gun
	modify_mounted_gun()
	return TRUE

/obj/machinery/deployable_turret/proc/modify_mounted_gun()
	if (isnull(mounted_gun))
		return FALSE

	RegisterSignal(mounted_gun, COMSIG_ITEM_DROPPED, PROC_REF(mounted_gun_dropped))

	mounted_gun.projectile_damage_multiplier *= damage_mult
	mounted_gun.fire_delay /= fire_rate_mult
	mounted_gun.recoil *= recoil_mult
	mounted_gun.spread *= recoil_mult

	return TRUE

/obj/machinery/deployable_turret/proc/unmodify_mounted_gun()
	if (isnull(mounted_gun))
		return FALSE

	UnregisterSignal(mounted_gun, list(COMSIG_ITEM_DROPPED))

	mounted_gun.projectile_damage_multiplier /= damage_mult
	mounted_gun.fire_delay *= fire_rate_mult
	mounted_gun.recoil /= recoil_mult
	mounted_gun.spread /= recoil_mult

	return TRUE

/// Undeploying, for when you want to move your big dakka around
/obj/machinery/deployable_turret/wrench_act(mob/living/user, obj/item/wrench/used_wrench)
	. = ..()
	if(!can_be_undeployed)
		return
	if(!ishuman(user))
		return
	used_wrench.play_tool_sound(user)
	user.balloon_alert(user, "undeploying...")
	if(!do_after(user, undeploy_time))
		return
	var/obj/undeployed_object = new spawned_on_undeploy(src)
	//Keeps the health the same even if you redeploy the gun
	undeployed_object.modify_max_integrity(max_integrity)
	qdel(src)

/obj/machinery/deployable_turret/attacked_by(obj/item/attacking_item, mob/living/user)
	if (!user.combat_mode && istype(attacking_item, /obj/item/gun))
		return (try_attach_gun(attacking_item, user))

	return ..()

/obj/machinery/deployable_turret/proc/try_attach_gun(obj/item/gun/new_gun, mob/living/user)
	if (!can_attach_gun(new_gun, user))
		return FALSE

	set_mounted_gun(new_gun)
	return TRUE

/obj/machinery/deployable_turret/proc/can_attach_gun(obj/item/gun/new_gun, mob/living/user, silent = FALSE)
	if (!isnull(mounted_gun))
		if (!silent)
			balloon_alert(user, "[mounted_gun] already attached!")
		return FALSE
	var/is_proper_type = FALSE
	for (var/obj/item/gun/typepath as anything in accepted_types)
		if (istype(new_gun, typepath))
			is_proper_type = TRUE
			break
	if (!is_proper_type)
		if (!silent)
			balloon_alert(user, "cant attach that!")
		return FALSE
	return TRUE

//BUCKLE HOOKS

/obj/machinery/deployable_turret/unbuckle_mob(mob/living/buckled_mob, force = FALSE, can_fall = TRUE)
	playsound(src,'sound/mecha/mechmove01.ogg', 50, TRUE)

	UnregisterSignal(buckled_mob, COMSIG_MOB_CLICKON)

	retract_gun(buckled_mob)
	if(istype(buckled_mob))
		buckled_mob.pixel_x = buckled_mob.base_pixel_x
		buckled_mob.pixel_y = buckled_mob.base_pixel_y
		if(buckled_mob.client)
			buckled_mob.client.view_size.resetToDefault()
	if(!always_anchored)
		set_anchored(FALSE)
	. = ..()
	STOP_PROCESSING(SSfastprocess, src)

/obj/machinery/deployable_turret/user_buckle_mob(mob/living/buckled_mob, mob/user, check_loc = TRUE)
	if(user.incapacitated() || !istype(user))
		return
	buckled_mob.forceMove(get_turf(src))
	. = ..()
	if(!.)
		return

	give_gun(buckled_mob)
	RegisterSignal(buckled_mob, COMSIG_MOB_CLICKON, PROC_REF(buckled_mob_clicked))

	buckled_mob.pixel_y = 14
	layer = ABOVE_MOB_LAYER
	SET_PLANE_IMPLICIT(src, GAME_PLANE_UPPER)
	setDir(SOUTH)
	playsound(src,'sound/mecha/mechmove01.ogg', 50, TRUE)
	set_anchored(TRUE)
	if(buckled_mob.client)
		buckled_mob.client.view_size.setTo(view_range)
	START_PROCESSING(SSfastprocess, src)

/obj/machinery/deployable_turret/proc/retract_gun(mob/living/buckled_mob)
	if (mounted_gun.loc == src)
		return FALSE

	balloon_alert(buckled_mob, "[mounted_gun] retracted")
	mounted_gun.forceMove(src)
	return TRUE

/obj/machinery/deployable_turret/proc/give_gun(mob/living/buckled_mob)
	if (mounted_gun.loc != src)
		return FALSE

	buckled_mob.drop_all_held_items()
	if (iscarbon(buckled_mob)) // basic mob integration soon
		var/mob/living/carbon/buckled_carbon = buckled_mob
		INVOKE_ASYNC(buckled_carbon, TYPE_PROC_REF(/mob/living/carbon, put_in_hands), mounted_gun)
	balloon_alert(buckled_mob, "grabbed [mounted_gun]")
	return TRUE

/obj/machinery/deployable_turret/process()
	if (!update_positioning())
		return PROCESS_KILL

/obj/machinery/deployable_turret/proc/update_positioning()
	if (!LAZYLEN(buckled_mobs))
		return FALSE
	var/mob/living/controller = buckled_mobs[1]
	if(!istype(controller))
		return FALSE
	var/client/controlling_client = controller.client
	if(controlling_client)
		var/modifiers = params2list(controlling_client.mouseParams)
		var/atom/target_atom = controlling_client.mouse_object_ref?.resolve()
		var/turf/target_turf = get_turf(target_atom)
		if(istype(target_turf)) //They're hovering over something in the map.
			direction_track(controller, target_turf)
			calculated_projectile_vars = calculate_projectile_angle_and_pixel_offsets(controller, target_turf, modifiers)

/obj/machinery/deployable_turret/proc/direction_track(mob/user, atom/targeted)
	if(user.incapacitated())
		return
	setDir(get_dir(src,targeted))
	user.setDir(dir)
	switch(dir)
		if(NORTH)
			layer = BELOW_MOB_LAYER
			SET_PLANE_IMPLICIT(src, GAME_PLANE)
			user.pixel_x = 0
			user.pixel_y = -14
		if(NORTHEAST)
			layer = BELOW_MOB_LAYER
			SET_PLANE_IMPLICIT(src, GAME_PLANE)
			user.pixel_x = -8
			user.pixel_y = -4
		if(EAST)
			layer = ABOVE_MOB_LAYER
			SET_PLANE_IMPLICIT(src, GAME_PLANE_UPPER)
			user.pixel_x = -14
			user.pixel_y = 0
		if(SOUTHEAST)
			layer = BELOW_MOB_LAYER
			SET_PLANE_IMPLICIT(src, GAME_PLANE)
			user.pixel_x = -8
			user.pixel_y = 4
		if(SOUTH)
			layer = ABOVE_MOB_LAYER
			SET_PLANE_IMPLICIT(src, GAME_PLANE_UPPER)
			plane = GAME_PLANE_UPPER
			user.pixel_x = 0
			user.pixel_y = 14
		if(SOUTHWEST)
			layer = BELOW_MOB_LAYER
			SET_PLANE_IMPLICIT(src, GAME_PLANE)
			user.pixel_x = 8
			user.pixel_y = 4
		if(WEST)
			layer = ABOVE_MOB_LAYER
			SET_PLANE_IMPLICIT(src, GAME_PLANE_UPPER)
			user.pixel_x = 14
			user.pixel_y = 0
		if(NORTHWEST)
			layer = BELOW_MOB_LAYER
			SET_PLANE_IMPLICIT(src, GAME_PLANE)
			user.pixel_x = 8
			user.pixel_y = -4

/obj/machinery/deployable_turret/proc/try_firing(atom/targeted_atom, mob/user, flag, params)
	target = targeted_atom
	if(target == user || user.incapacitated() || target == get_turf(src))
		return FALSE
	if (isnull(mounted_gun))
		return FALSE

	update_positioning()
	return (mounted_gun.fire_gun(targeted_atom, user, flag, params))

/obj/machinery/deployable_turret/proc/mounted_gun_dropped(datum/signal_source, mob/user)
	SIGNAL_HANDLER

	if (user in buckled_mobs)
		unbuckle_mob(user)
	else
		retract_gun(user)

/obj/machinery/deployable_turret/proc/buckled_mob_clicked(mob/signal_source, atom/target, params)
	SIGNAL_HANDLER

	if (target == mounted_gun || target == src || target == signal_source)
		return

	calculated_projectile_vars = calculate_projectile_angle_and_pixel_offsets(signal_source, target, params)
	direction_track(signal_source, target)
	update_positioning()

/obj/machinery/deployable_turret/ultimate  // Admin-only proof of concept for autoclicker automatics
	name = "Infinity Gun"
	view_range = 12

/obj/machinery/deployable_turret/hmg
	name = "heavy machine gun turret"
	desc = "A heavy calibre machine gun commonly used by Nanotrasen forces, famed for it's ability to give people on the recieving end more holes than normal."
	icon_state = "hmg"
	max_integrity = 250
	mounted_gun = /obj/item/gun/ballistic/automatic/l6_saw/unrestricted
	anchored = TRUE
	cooldown_duration = 2 SECONDS
	overheatsound = 'sound/weapons/gun/smg/smgrack.ogg'
	can_be_undeployed = TRUE
	spawned_on_undeploy = /obj/item/deployable_turret_folded

	fire_rate_mult = 1.5
	recoil_mult = 0.5

/obj/item/gun_control
	name = "turret controls"
	icon = 'icons/obj/weapons/hand.dmi'
	icon_state = "offhand"
	w_class = WEIGHT_CLASS_HUGE
	item_flags = ABSTRACT | NOBLUDGEON | DROPDEL
	resistance_flags = FIRE_PROOF | UNACIDABLE | ACID_PROOF
	var/obj/machinery/deployable_turret/turret

/obj/item/gun_control/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, ABSTRACT_ITEM_TRAIT)
	turret = loc
	if(!istype(turret))
		return INITIALIZE_HINT_QDEL

/obj/item/gun_control/Destroy()
	turret = null
	return ..()

/obj/item/gun_control/CanItemAutoclick()
	return TRUE

/obj/item/gun_control/attack_atom(obj/O, mob/living/user, params)
	user.changeNext_move(CLICK_CD_MELEE)
	O.attacked_by(src, user)

/obj/item/gun_control/attack(mob/living/M, mob/living/user)
	M.lastattacker = user.real_name
	M.lastattackerckey = user.ckey
	M.attacked_by(src, user)
	add_fingerprint(user)

/obj/item/gun_control/afterattack(atom/targeted_atom, mob/user, flag, params)
	. = ..()
	. |= AFTERATTACK_PROCESSED_ITEM
	var/modifiers = params2list(params)
	var/obj/machinery/deployable_turret/turret = user.buckled
	turret.calculated_projectile_vars = calculate_projectile_angle_and_pixel_offsets(user, targeted_atom, modifiers)
	turret.direction_track(user, targeted_atom)
	turret.try_firing(targeted_atom, user, flag, params)
