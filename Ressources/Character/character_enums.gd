class_name CharacterEnums

enum Attribute {
	KOERPERKRAFT,
	GEWANDHEIT,
	ROBUSTHEIT,
	WILLENSKRAFT,
	VERSTAND,
	BEWUSSTSEIN,
	PRAESENZ,
}

enum Ausbildung {
	KEINE,
	KRIEGER,
	GELEHRTER,
	HANDWERKER,
}

enum Spezies {
	KEINE,
	MENSCH,
	ELF,
	ZWERG,
}

enum Herkunft {
	KEINE,
	WAISE,
	ADELIG,
	BUERGERLICH,
}

enum Besonderheit {
	KEINE,
	MUTIG,
	FEINFUEHLIG,
	GEDULDIG,
}


const XP_PRO_FAEHIGKEITSLEVEL := 100
const STANDARD_FAEHIGKEITS_CAP := 10
const MAX_AKTIVES_TRAINING := 5
const FAEHIGKEITEN_PRO_ATTRIBUT := 5
const MAX_BESONDERHEITEN := 2
const BEZIEHUNG_MIN := -10
const BEZIEHUNG_MAX := 10


static func attribute_name(attr: Attribute) -> String:
	match attr:
		Attribute.KOERPERKRAFT: return "Körperkraft"
		Attribute.GEWANDHEIT: return "Gewandheit"
		Attribute.ROBUSTHEIT: return "Robustheit"
		Attribute.WILLENSKRAFT: return "Willenskraft"
		Attribute.VERSTAND: return "Verstand"
		Attribute.BEWUSSTSEIN: return "Bewusstsein"
		Attribute.PRAESENZ: return "Präsenz"
		_: return "Unbekannt"


static func is_physical(attr: Attribute) -> bool:
	return attr in [Attribute.KOERPERKRAFT, Attribute.GEWANDHEIT, Attribute.ROBUSTHEIT]


static func is_mental(attr: Attribute) -> bool:
	return attr in [Attribute.WILLENSKRAFT, Attribute.VERSTAND, Attribute.BEWUSSTSEIN]
