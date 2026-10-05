class_name Layers
extends RefCounted
## Fysica-lagen (collision_layer/-mask bits). Eén plek, zodat iedereen dezelfde gebruikt.

const TERRAIN := 1 << 0
const LOOT := 1 << 1
const PLAYERS := 1 << 2
const DEBRIS := 1 << 3
const CRUST := 1 << 4
const LIFT := 1 << 5
const INTERACT := 1 << 6
## Onzichtbare muren aan de concessiegrens (enkel spelers botsen ertegen).
const BOUNDS := 1 << 7
## Puin van een instorting of beving dat blijft liggen (spelers botsen ertegen; Rubble).
const RUBBLE := 1 << 8
