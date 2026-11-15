--!strict
--[[
	InputBus — une action, trois facons de la lancer : une touche, un bouton
	de manette, un bouton tactile (choisi avec Josh le 15 novembre 2026 : le
	jeu doit se jouer au telephone).

	Chaque action se lie comme avec ContextActionService (memes arguments) ;
	le bus garde sa fonction. Un bouton tactile appelle `fire` avec le bouton
	de manette qu'il remplace : l'action fait exactement ce qu'elle ferait a
	la manette (courir bascule, L1 / R1 choisissent le sens), sans une
	deuxieme copie de sa logique.
]]

local ContextActionService = game:GetService("ContextActionService")

local InputBus = {}

type Handler = (string, Enum.UserInputState, InputObject) -> any

local handlers: { [string]: Handler } = {}

function InputBus.bind(name: string, fn: Handler, _touchButton: boolean, ...: any)
	handlers[name] = fn
	ContextActionService:BindAction(name, fn, false, ...)
end

function InputBus.bindAtPriority(
	name: string,
	fn: Handler,
	_touchButton: boolean,
	priority: number,
	...: any
)
	handlers[name] = fn
	ContextActionService:BindActionAtPriority(name, fn, false, priority, ...)
end

-- Lance l'action `name` comme si on avait appuye (Begin) ou relache (End) le
-- bouton de manette `gamepad`. Rend ce que l'action rend (Sink, Pass), ou
-- nil si elle n'est pas liee.
function InputBus.fire(name: string, state: Enum.UserInputState, gamepad: string?): any
	local fn = handlers[name]
	if fn == nil then
		return nil
	end
	local code = if gamepad then (Enum.KeyCode :: any)[gamepad] else Enum.KeyCode.None
	local fake = {
		KeyCode = code,
		UserInputType = Enum.UserInputType.Touch,
		UserInputState = state,
		Position = Vector3.zero,
		Delta = Vector3.zero,
	}
	return fn(name, state, fake :: any)
end

return InputBus
