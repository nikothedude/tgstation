/obj/machinery/rnd/production/techfab
	name = "technology fabricator"
	desc = "Produces researched prototypes with raw materials and energy."
	icon_state = "protolathe"
	circuit = /obj/item/circuitboard/machine/techfab
	console_link = FALSE
	production_animation = "protolathe_n"
	allowed_buildtypes = PROTOLATHE | IMPRINTER


/obj/machinery/rnd/production/techfab/Initialize(mapload)
	. = ..()

	reagents.flags &= ~REFILLABLE // apparantly, according to the person that did the tgui, this shti dont support reagents anymore
