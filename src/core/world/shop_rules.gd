extends RefCounted

const InventoryRules = preload("res://src/core/world/inventory_rules.gd")
const MAX_VALUE := 2147483647


static func valid_shop(shop: ShopData) -> bool:
	if shop == null or shop.shop_id.is_empty() or shop.shop_id != shop.shop_id.strip_edges():
		return false
	var ids: Dictionary = {}
	for entry in shop.entries:
		if entry == null or entry.item == null:
			return false
		var item := entry.item
		if item.item_id.is_empty() or item.item_id != item.item_id.strip_edges() or ids.has(item.item_id) or not item.world_object_id.is_empty():
			return false
		if item.max_stack < 1 or not is_finite(item.weight) or item.weight < 0:
			return false
		if entry.stock < -1 or entry.stock > MAX_VALUE or entry.buy_price < 0 or entry.buy_price > MAX_VALUE or entry.sell_price < 0 or entry.sell_price > MAX_VALUE:
			return false
		ids[item.item_id] = true
	return true


static func sell_price(shop: ShopData, item: ItemData) -> int:
	for entry in shop.entries:
		if entry and entry.item and entry.item.item_id == item.item_id:
			return entry.sell_price
	if not is_finite(item.weight) or item.weight < 0 or item.weight > MAX_VALUE / 10.0:
		return -1
	return maxi(1, int(item.weight * 10))


## Vorbereiten auf denselben Arbeitskopien wie andere WorldRules-Effekte.
static func apply(world: WorldState, inventories: Dictionary, gold: Dictionary, stocks: Dictionary, effect: Dictionary) -> bool:
	if effect.size() != 5 or not effect.get("count") is int or effect.count != 1 or not effect.get("shop_id") is String:
		return false
	var shop: ShopData = world.shops.get(effect.shop_id)
	if not valid_shop(shop):
		return false
	var inventory := InventoryRules.stage(world, inventories, effect.get("character_id"))
	if inventory == null:
		return false
	var character := world.characters.get_character(effect.character_id)
	var current: int = gold.get(effect.character_id, character.gold)
	if current < 0 or current > MAX_VALUE:
		return false
	if effect.type == "shop_buy":
		if not effect.get("item_id") is String:
			return false
		var offer: ShopEntry = null
		for entry in shop.entries:
			if entry.item.item_id == effect.item_id:
				offer = entry
		if offer == null:
			return false
		if not stocks.has(shop.shop_id):
			stocks[shop.shop_id] = {}
		var stock: int = stocks[shop.shop_id].get(effect.item_id, offer.stock)
		if stock == 0 or current < offer.buy_price:
			return false
		var working := character.duplicate() as CharacterResource
		working.inventory = inventory
		if not working.can_carry_additional(offer.item.weight):
			return false
		inventory.add_item(offer.item.duplicate_item(), 1)
		gold[effect.character_id] = current - offer.buy_price
		stocks[shop.shop_id][effect.item_id] = stock - 1 if stock > 0 else -1
		return true
	if effect.type != "shop_sell" or not InventoryRules.valid_selector(effect):
		return false
	var item: ItemData = null
	# Gleiche Auswahlreihenfolge wie remove_item in InventoryRules.
	for i in range(inventory.slots.size() - 1, -1, -1):
		if InventoryRules.matches(inventory.slots[i].item, effect):
			item = inventory.slots[i].item
			break
	if item == null:
		return false
	var price := sell_price(shop, item)
	if price < 0 or current + price > MAX_VALUE:
		return false
	var removal := effect.duplicate()
	removal.erase("shop_id")
	removal.type = "remove_item"
	if not InventoryRules.apply(world, inventories, removal):
		return false
	gold[effect.character_id] = current + price
	# Bestehende Regel: Verkauf stockt kein Angebot auf (kein Rückkauf).
	return true
