--!strict
--[[
	La traduction (choisie avec Josh le 15 novembre 2026 : le jeu en anglais
	pour qui ne joue pas en francais). Le jeu s'ecrit en francais ; un
	dictionnaire (Strings) donne l'anglais de chaque texte, et le client
	(Localizer) remplace ce qui s'affiche.

	Une cle sans format (« Prêt ») se remplace telle quelle. Une cle avec des
	formats (« Restants : %d ») devient un motif : chaque morceau variable est
	repris dans l'anglais a sa place ({1}, {2}...), et traduit a son tour s'il
	est lui-meme dans le dictionnaire (un nom d'objet, un titre de Regard).
	Un texte se traduit ligne par ligne, et par morceaux separes de trois
	espaces (les ecrans collent ainsi plusieurs informations).

	Logique pure : le dictionnaire arrive en argument.
]]

local Lang = {}

export type Pattern = { match: string, en: string, weight: number }
export type Compiled = {
	exact: { [string]: string },
	patterns: { Pattern },
}

-- string.upper ne touche pas aux lettres accentuees (UTF-8).
local ACCENTS = {
	["é"] = "É",
	["è"] = "È",
	["ê"] = "Ê",
	["ë"] = "Ë",
	["à"] = "À",
	["â"] = "Â",
	["ç"] = "Ç",
	["ô"] = "Ô",
	["î"] = "Î",
	["ï"] = "Ï",
	["û"] = "Û",
	["ù"] = "Ù",
	["œ"] = "Œ",
}

function Lang.upper(s: string): string
	local out = string.upper(s)
	for low, up in ACCENTS do
		out = string.gsub(out, low, up)
	end
	return out
end

local SPEC = "%%[%d%.]*[sdf]"
local MAGIC = "([%^%$%(%)%.%[%]%*%+%-%?%%])"

function Lang.isPattern(key: string): boolean
	return string.find(key, SPEC) ~= nil
end

-- Le motif Lua d'un format francais : les morceaux fixes echappes, chaque
-- format remplace par une capture.
local function toMatch(key: string): string
	local out, at = "^", 1
	while true do
		local s, e = string.find(key, SPEC, at)
		if s == nil then
			break
		end
		out ..= string.gsub(string.sub(key, at, s - 1), MAGIC, "%%%1")
		local spec = string.sub(key, s, e)
		local kind = string.sub(spec, -1)
		out ..= if kind == "s" then "(.+)" elseif kind == "d" then "(%-?%d+)" else "(%-?[%d%.,]+)"
		at = e + 1
	end
	return out .. string.gsub(string.sub(key, at), MAGIC, "%%%1") .. "$"
end

function Lang.compile(dictionary: { [string]: string }): Compiled
	local exact: { [string]: string } = {}
	local patterns: { Pattern } = {}
	for fr, en in dictionary do
		if Lang.isPattern(fr) then
			-- Le plus precis d'abord : celui qui a le plus de texte fixe.
			local fixed = string.gsub(fr, SPEC, "")
			table.insert(patterns, { match = toMatch(fr), en = en, weight = #fixed })
		else
			exact[fr] = en
			-- Les titres en capitales (« LÉGENDAIRE ») se traduisent aussi.
			local up = Lang.upper(fr)
			if exact[up] == nil then
				exact[up] = string.upper(en)
			end
		end
	end
	table.sort(patterns, function(a, b)
		if a.weight ~= b.weight then
			return a.weight > b.weight
		end
		return a.match < b.match
	end)
	return { exact = exact, patterns = patterns }
end

local translatePiece: (Compiled, string, number) -> string?

-- Un morceau variable : un nombre reste, un texte connu se traduit, une
-- liste (« La rage, Le flair ») se traduit element par element.
local function capture(c: Compiled, s: string, depth: number): string
	if depth > 3 or tonumber(s) then
		return s
	end
	local whole = translatePiece(c, s, depth + 1)
	if whole then
		return whole
	end
	if string.find(s, ", ", 1, true) then
		local parts = string.split(s, ", ")
		for i, p in parts do
			parts[i] = translatePiece(c, p, depth + 1) or p
		end
		return table.concat(parts, ", ")
	end
	return s
end

translatePiece = function(c: Compiled, s: string, depth: number): string?
	local hit = c.exact[s]
	if hit then
		return hit
	end
	for _, p in c.patterns do
		local caps = { string.match(s, p.match) }
		if #caps > 0 then
			return (
				string.gsub(p.en, "{(%d)}", function(n: string): string
					local v = caps[tonumber(n) :: number]
					return if v then capture(c, v, depth) else ""
				end)
			)
		end
	end
	return nil
end

-- Le texte en anglais, ou nil si rien n'y est connu (il reste tel quel).
-- `unknown` recoit chaque morceau inconnu (pour les reperer dans Studio).
function Lang.translate(c: Compiled, text: string, unknown: ((string) -> ())?): string?
	if text == "" then
		return nil
	end
	-- Toujours morceau par morceau : un motif pris sur le texte entier
	-- avalerait les morceaux suivants dans sa derniere capture.
	local changed = false
	local lines = string.split(text, "\n")
	for i, line in lines do
		local pieces = string.split(line, "   ")
		for j, piece in pieces do
			local t = if piece == "" then nil else translatePiece(c, piece, 0)
			if t then
				pieces[j] = t
				changed = true
			elseif piece ~= "" and unknown then
				unknown(piece)
			end
		end
		lines[i] = table.concat(pieces, "   ")
	end
	return if changed then table.concat(lines, "\n") else nil
end

return Lang
