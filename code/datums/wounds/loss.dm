/datum/wound_pregen_data/loss
	abstract = FALSE

	wound_path_to_generate = /datum/wound/loss
	required_limb_biostate = NONE
	check_for_any = TRUE

/datum/wound/loss
	name = "Dismemberment Wound"
	desc = "oof ouch!!"

	sound_effect = 'sound/effects/dismember.ogg'
	severity = WOUND_SEVERITY_LOSS
	threshold_minimum = WOUND_DISMEMBER_OUTRIGHT_THRESH // not actually used since dismembering is handled differently, but may as well assign it since we got it
	status_effect_type = null
	scar_keyword = "dismember"
	wound_flags = null
	already_scarred = TRUE // We manually assign scars for dismembers through endround missing limbs and aheals

	var/loss_wound_type

/// Our special proc for our special dismembering, the wounding type only matters for what text we have
/datum/wound/loss/proc/apply_dismember(obj/item/bodypart/dismembered_part, wounding_type = WOUND_SLASH, outright = FALSE, attack_direction)
	if(!istype(dismembered_part) || !dismembered_part.owner || !(dismembered_part.body_zone in get_viable_zones()) || isalien(dismembered_part.owner) || !dismembered_part.can_dismember())
		qdel(src)
		return

	set_victim(dismembered_part.owner)
	var/self_msg

	if(dismembered_part.body_zone == BODY_ZONE_CHEST)
		occur_text = "is split open, causing [victim.p_their()] internal organs to spill out!"
		self_msg = "is split open, causing your internal organs to spill out!"
	else
		occur_text = dismembered_part.get_dismember_message(wounding_type, outright)

	var/msg = span_bolddanger("[victim]'s [dismembered_part.plaintext_zone] [occur_text]")

	victim.visible_message(msg, span_userdanger("Your [dismembered_part.plaintext_zone] [self_msg ? self_msg : occur_text]"))

	loss_wound_type = wounding_type

	set_limb(dismembered_part)
	second_wind()
	log_wound(victim, src)
	if(dismembered_part.can_bleed() && wounding_type != WOUND_BURN && victim.blood_volume)
		victim.spray_blood(attack_direction, severity)
	dismembered_part.dismember(wounding_type == WOUND_BURN ? BURN : BRUTE, wound_type = wounding_type)
	qdel(src)
	return TRUE

/obj/item/bodypart/proc/get_dismember_message(wounding_type, outright)
	var/occur_text

	if(outright)
		switch(wounding_type)
			if(WOUND_BLUNT)
				occur_text = "is outright smashed to a gross pulp, severing it completely!"
			if(WOUND_SLASH)
				occur_text = "is outright slashed off, severing it completely!"
			if(WOUND_PIERCE)
				occur_text = "is outright blasted apart, severing it completely!"
			if(WOUND_BURN)
				occur_text = "is outright incinerated, falling to dust!"
	else
		var/bone_text
		if (biological_state & BIO_BONE)
			bone_text = "bone"
		else if (biological_state & BIO_METAL)
			bone_text = "metal"

		var/tissue_text
		if (biological_state & BIO_FLESH)
			tissue_text = "flesh"
		else if (biological_state & BIO_WIRED)
			tissue_text = "wire"

		switch(wounding_type)
			if(WOUND_BLUNT)
				occur_text = "is shattered through the last [bone_text] holding it together, severing it completely!"
			if(WOUND_SLASH)
				occur_text = "is slashed through the last [tissue_text] holding it together, severing it completely!"
			if(WOUND_PIERCE)
				occur_text = "is pierced through the last [tissue_text] holding it together, severing it completely!"
			if(WOUND_BURN)
				occur_text = "is completely incinerated, falling to dust!"

	return occur_text

/datum/wound/loss/get_scar_file(obj/item/bodypart/scarred_limb, add_to_scars)
	if (scarred_limb.biological_state & BIO_FLESH)
		return FLESH_SCAR_FILE
	if (scarred_limb.biological_state & BIO_BONE)
		return BONE_SCAR_FILE

	return ..()
