class_name NPCDialogueTopic extends Resource

## Eine Frage am Ende eines Gesprächszweigs; Ziel ist ein Titel der Dialogdatei.
@export var label: String = ""
@export var title: String = ""
## Optional: nur anbieten, wenn der aktuelle Gesprächspartner dieses Wissen hat.
@export var required_fact_id: String = ""
