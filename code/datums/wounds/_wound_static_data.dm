// This datum is merely a singleton instance that allows for custom "can be applied" behaviors without instantiating a wound instance.
// For example: You can make a pregen_data subtype for your wound that overrides can_be_applied_to to only apply to specifically slimeperson limbs.
// Without this, youre stuck with very static initial variables.

/// A singleton datum that holds pre-gen and static data about a wound. Each wound datum should have a corresponding wound_pregen_data.
/datum/wound_pregen_data
	/// The typepath of the wound we will be handling and storing data of. NECESSARY IF THIS IS A NON-ABSTRACT TYPE!
	var/datum/wound/wound_path_to_generate

	/// Will this be instantiated?
	var/abstract = FALSE

	/// If true, our wound can be selected in ordinary wound rolling. If this is set to false, our wound can only be directly instantiated by use of specific typepath.
	var/can_be_randomly_generated = TRUE

	/// A list of biostates a limb must have to receive our wound, in wounds.dm.
	var/required_limb_biostate
	/// If false, we will check if the limb has all of our required biostates instead of just any.
	var/require_any_biostate = FALSE

	/// If false, we will iterate through wounds on a given limb, and if any match our type, we wont add our wound.
	var/duplicates_allowed = FALSE

	/// If we require BIO_BLOODED, we will not add our wound if this is true and the limb cannot bleed.
	var/ignore_cannot_bleed = TRUE // a lot of bleed wounds should still be applied for purposes of mangling flesh

	/// A list of bodyzones we are applicable to.
	var/list/viable_zones = list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	/// The type of attack that can generate this wound. E.g. WOUND_SLASH = A sword can cause us, or WOUND_BLUNT = a hammer can cause us/a sword attacking mangled flesh.
	var/list/required_wound_types
	var/match_all_wound_types = FALSE

	var/weight = WOUND_DEFAULT_WEIGHT

	var/threshold_minimum

	/// The series of wounds this is in. See wounds.dm (the defines file) for a more detailed explanation - but tldr is that no 2 wounds of the same series can be on a limb.
	var/wound_series

	var/specific_type = WOUND_SPECIFIC_TYPE_BASIC

	var/compete_for_wounding = TRUE
	var/competition_mode = WOUND_COMPETITION_SUBMIT

	/// A list of BIO_ defines that will be iterated over in order to determine the scar file our wound will generate.
	/// Use generate_scar_priorities to create a custom list.
	var/list/scar_priorities

/datum/wound_pregen_data/New()
	. = ..()

	if (!abstract)
		if (required_limb_biostate == null)
			stack_trace("required_limb_biostate null - please set it! occured on: [src.type]")
		if (wound_path_to_generate == null)
			stack_trace("wound_path_to_generate null - please set it! occured on: [src.type]")

	scar_priorities = generate_scar_priorities()

/datum/wound_pregen_data/proc/generate_scar_priorities()
	RETURN_TYPE(/list)

	var/list/priorities = list(
		"[BIO_FLESH]",
		"[BIO_BONE]",
	)

	return priorities

// this proc is the primary reason this datum exists - a singleton instance so we can always run this proc even without the wound existing
/**
 * Args:
 * * obj/item/bodypart/limb: The limb we are considering.
 * * wound_type: The type of the "wound acquisition attempt". Example: A slashing attack cannot proc a blunt wound, so wound_type = WOUND_SLASH would
 * fail if we expect WOUND_BLUNT. Defaults to the wound type we expect.
 * * datum/wound/old_wound: If we would replace a wound, this would be said wound. Nullable.
 * * random_roll = FALSE: If this is in the context of a random wound generation, and this wound wasn't specifically checked.
 *
 * Returns:
 * FALSE if the limb cannot be wounded, if wound_type is not ours, if we have a higher severity wound already in our series,
 * if we have a biotype mismatch, if the limb isnt in a viable zone, or if theres any duplicate wound types.
 * TRUE otherwise.
 */
/datum/wound_pregen_data/proc/can_be_applied_to(obj/item/bodypart/limb, list/wound_types = required_wound_types, datum/wound/old_wound, random_roll = FALSE, duplicates_allowed = src.duplicates_allowed, care_about_existing_wounds = TRUE)
	SHOULD_BE_PURE(TRUE)

	if (!istype(limb) || !limb.owner)
		return FALSE

	if (random_roll && !can_be_randomly_generated)
		return FALSE

	if (HAS_TRAIT(limb.owner, TRAIT_NEVER_WOUNDED) || (limb.owner.status_flags & GODMODE))
		return FALSE

	if (!wound_types_valid(wound_types))
		return FALSE

	if (care_about_existing_wounds)
		for (var/datum/wound/preexisting_wound as anything in limb.wounds)
			var/datum/wound_pregen_data/pregen_data = GLOB.all_wound_pregen_data[preexisting_wound.type]
			if (pregen_data.wound_series == wound_series)
				if (preexisting_wound.severity >= initial(wound_path_to_generate.severity))
					return FALSE

	if (!ignore_cannot_bleed && ((required_limb_biostate & BIO_BLOODED) && !limb.can_bleed()))
		return FALSE

	if (!biostate_valid(limb.biological_state))
		return FALSE

	if (!(limb.body_zone in viable_zones))
		return FALSE

	// we accept promotions and demotions, but no point in redundancy. This should have already been checked wherever the wound was rolled and applied for (see: bodypart damage code), but we do an extra check
	// in case we ever directly add wounds
	if (!duplicates_allowed)
		for (var/datum/wound/preexisting_wound as anything in limb.wounds)
			if (preexisting_wound.type == wound_path_to_generate && (preexisting_wound != old_wound))
				return FALSE
	return TRUE

/// Returns true if we have the given biostates, or any biostate in it if check_for_any is true. False otherwise.
/datum/wound_pregen_data/proc/biostate_valid(biostate)
	if (require_any_biostate)
		if (!(biostate & required_limb_biostate))
			return FALSE
	else if (!((biostate & required_limb_biostate) == required_limb_biostate)) // check for all
		return FALSE

	return TRUE

/datum/wound_pregen_data/proc/get_weight()
	return weight

/datum/wound_pregen_data/proc/wound_types_valid(list/wound_types)
	if (WOUND_ALL in required_wound_types)
		return TRUE
	if (!length(wound_types))
		return FALSE

	for (var/type as anything in wound_types)
		if (!(type in required_wound_types))
			if (match_all_wound_types)
				return FALSE
		else
			if (!match_all_wound_types)
				return TRUE

	return match_all_wound_types // if we get here, we've matched everything

/datum/wound_pregen_data/proc/get_threshold_for(obj/item/bodypart/part, attack_direction, damage_source)
	return threshold_minimum

/// Returns a new instance of our wound datum.
/datum/wound_pregen_data/proc/generate_instance(obj/item/bodypart/limb, ...)
	RETURN_TYPE(/datum/wound)

	return new wound_path_to_generate

/datum/wound_pregen_data/Destroy(force, ...)
	stack_trace("[src], a singleton wound pregen data instance, was destroyed! This should not happen!")

	if (!force)
		return QDEL_HINT_LETMELIVE

	. = ..()

	GLOB.all_wound_pregen_data[wound_path_to_generate] = new src.type //recover
