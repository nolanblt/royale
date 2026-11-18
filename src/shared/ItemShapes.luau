--!strict
--[[
	ItemShapes — le dessin de chaque objet de la partie (Josh, le 16 novembre
	2026 : « que tu les modelises, qu'ils apparaissent dans la main »).

	Donnees pures, sans Roblox : ItemModels (Effets) les construit. Chaque
	objet est une liste de pieces, dans le repere de la main droite : le
	poing a l'origine, +Y sort du poing vers le haut, -Z vers l'avant (en
	studs, angles en degres).

	Une piece : s (Block, Ball, Cyl, Wedge, Egg), z (taille), p (position),
	r (rotation), c (couleur), m (matiere de Roblox), t (transparence), f
	(reflet), l ({ portee, eclat } : une lumiere de sa couleur).
	Cyl : z = { diametre, longueur, diametre }, couche le long de Y.
	Egg : une boule etiree a sa taille (Ball reste une sphere du plus petit
	cote).
]]

export type Piece = {
	s: string,
	z: { number },
	p: { number }?,
	r: { number }?,
	c: { number },
	m: string?,
	t: number?,
	f: number?,
	l: { number }?,
}

-- Les couleurs reviennent : une palette commune garde les objets du meme
-- monde (rouille, bois use, metal sombre, la braise de l'Oeil).
local IRON = { 58, 58, 62 }
local STEEL = { 150, 152, 158 }
local RUST = { 120, 62, 38 }
local WOOD = { 122, 86, 54 }
local DARKWOOD = { 74, 50, 34 }
local BRASS = { 196, 150, 70 }
local EMBER = { 255, 90, 40 }
local BLOOD = { 200, 30, 30 }
local BONE = { 228, 220, 200 }
local CLOTH = { 52, 40, 58 }
local CARDBOARD = { 176, 136, 92 }
local OLIVE = { 84, 96, 60 }
local GLASS = { 190, 225, 215 }

local shapes: { [string]: { Piece } } = {
	-- Une boite de fumee militaire : corps olive, coiffe et levier d'acier.
	smoke = {
		{ s = "Cyl", z = { 0.5, 0.9, 0.5 }, p = { 0, 0.15, 0 }, c = OLIVE, m = "Metal" },
		{ s = "Cyl", z = { 0.52, 0.14, 0.52 }, p = { 0, 0.66, 0 }, c = STEEL, m = "Metal" },
		{ s = "Cyl", z = { 0.2, 0.12, 0.2 }, p = { 0, 0.78, 0 }, c = IRON, m = "Metal" },
		{
			s = "Block",
			z = { 0.1, 0.62, 0.16 },
			p = { 0.27, 0.42, 0 },
			r = { 0, 0, -6 },
			c = STEEL,
			m = "Metal",
		},
		{
			s = "Cyl",
			z = { 0.16, 0.04, 0.16 },
			p = { -0.16, 0.8, 0 },
			r = { 90, 0, 0 },
			c = BRASS,
			m = "Metal",
		},
		{
			s = "Cyl",
			z = { 0.52, 0.06, 0.52 },
			p = { 0, 0.1, 0 },
			c = { 220, 200, 60 },
			m = "SmoothPlastic",
		},
	},
	-- Un gros petard rouge a bandes d'or, meche noire et braise au bout.
	firecracker = {
		{
			s = "Cyl",
			z = { 0.32, 0.85, 0.32 },
			p = { 0, 0.15, 0 },
			c = { 190, 24, 24 },
			m = "SmoothPlastic",
		},
		{ s = "Cyl", z = { 0.34, 0.06, 0.34 }, p = { 0, 0.42, 0 }, c = BRASS, m = "Metal" },
		{ s = "Cyl", z = { 0.34, 0.06, 0.34 }, p = { 0, -0.12, 0 }, c = BRASS, m = "Metal" },
		{
			s = "Cyl",
			z = { 0.05, 0.35, 0.05 },
			p = { 0.04, 0.72, 0 },
			r = { 0, 0, -18 },
			c = { 20, 20, 20 },
		},
		{
			s = "Ball",
			z = { 0.1, 0.1, 0.1 },
			p = { 0.1, 0.9, 0 },
			c = EMBER,
			m = "Neon",
			l = { 4, 1 },
		},
	},
	-- Une fusee de detresse : tube orange, bouchon blanc, grattoir sombre.
	flare = {
		{
			s = "Cyl",
			z = { 0.28, 1.1, 0.28 },
			p = { 0, 0.2, 0 },
			c = { 235, 110, 30 },
			m = "SmoothPlastic",
		},
		{ s = "Cyl", z = { 0.3, 0.18, 0.3 }, p = { 0, 0.82, 0 }, c = BONE, m = "SmoothPlastic" },
		{ s = "Cyl", z = { 0.3, 0.1, 0.3 }, p = { 0, -0.38, 0 }, c = IRON, m = "Metal" },
		{
			s = "Cyl",
			z = { 0.29, 0.22, 0.29 },
			p = { 0, 0.42, 0 },
			c = BONE,
			m = "SmoothPlastic",
			t = 0.2,
		},
	},
	-- Un baton de craie, use au bout.
	chalk = {
		{
			s = "Cyl",
			z = { 0.18, 0.6, 0.18 },
			p = { 0, 0.25, 0 },
			c = { 245, 242, 232 },
			m = "Concrete",
		},
		{
			s = "Cyl",
			z = { 0.13, 0.08, 0.13 },
			p = { 0, 0.59, 0 },
			c = { 245, 242, 232 },
			m = "Concrete",
		},
	},
	-- Une bouteille de verre vert, epaule ronde, goulot, capsule.
	bottle = {
		{
			s = "Cyl",
			z = { 0.42, 0.75, 0.42 },
			p = { 0, 0.05, 0 },
			c = { 40, 110, 60 },
			m = "Glass",
			t = 0.25,
		},
		{
			s = "Ball",
			z = { 0.42, 0.42, 0.42 },
			p = { 0, 0.42, 0 },
			c = { 40, 110, 60 },
			m = "Glass",
			t = 0.25,
		},
		{
			s = "Cyl",
			z = { 0.16, 0.45, 0.16 },
			p = { 0, 0.78, 0 },
			c = { 40, 110, 60 },
			m = "Glass",
			t = 0.25,
		},
		{ s = "Cyl", z = { 0.19, 0.06, 0.19 }, p = { 0, 1.02, 0 }, c = STEEL, m = "Metal" },
		{ s = "Cyl", z = { 0.43, 0.3, 0.43 }, p = { 0, 0.02, 0 }, c = BONE, m = "SmoothPlastic" },
	},
	-- Un bidon d'huile cabosse : corps rouge sombre, bec et poignee.
	oil = {
		{
			s = "Block",
			z = { 0.36, 0.8, 0.62 },
			p = { 0, 0.2, 0 },
			c = { 120, 20, 20 },
			m = "Metal",
		},
		{ s = "Block", z = { 0.38, 0.08, 0.64 }, p = { 0, 0.62, 0 }, c = IRON, m = "Metal" },
		{
			s = "Cyl",
			z = { 0.1, 0.5, 0.1 },
			p = { 0, 0.8, -0.28 },
			r = { -40, 0, 0 },
			c = BRASS,
			m = "Metal",
		},
		{ s = "Block", z = { 0.08, 0.08, 0.36 }, p = { 0, 0.78, 0.1 }, c = IRON, m = "Metal" },
		{
			s = "Block",
			z = { 0.37, 0.2, 0.5 },
			p = { 0, 0.22, 0 },
			c = { 230, 200, 60 },
			m = "SmoothPlastic",
		},
	},
	-- Une lampe torche tenue pointee devant : corps noir, tete large,
	-- verre qui eclaire.
	torch = {
		{
			s = "Cyl",
			z = { 0.3, 0.95, 0.3 },
			p = { 0, 0.05, -0.2 },
			r = { 90, 0, 0 },
			c = IRON,
			m = "Metal",
		},
		{
			s = "Cyl",
			z = { 0.44, 0.3, 0.44 },
			p = { 0, 0.05, -0.75 },
			r = { 90, 0, 0 },
			c = IRON,
			m = "Metal",
		},
		{
			s = "Cyl",
			z = { 0.38, 0.04, 0.38 },
			p = { 0, 0.05, -0.91 },
			r = { 90, 0, 0 },
			c = { 255, 245, 200 },
			m = "Neon",
			l = { 10, 2 },
		},
		{
			s = "Block",
			z = { 0.1, 0.05, 0.18 },
			p = { 0, 0.22, -0.3 },
			c = BLOOD,
			m = "SmoothPlastic",
		},
	},
	-- Une clochette de laiton au manche de bois.
	bell = {
		{ s = "Cyl", z = { 0.14, 0.5, 0.14 }, p = { 0, 0.15, 0 }, c = DARKWOOD, m = "Wood" },
		{
			s = "Ball",
			z = { 0.36, 0.36, 0.36 },
			p = { 0, 0.52, 0 },
			c = BRASS,
			m = "Metal",
			f = 0.2,
		},
		{
			s = "Cyl",
			z = { 0.56, 0.36, 0.56 },
			p = { 0, 0.72, 0 },
			c = BRASS,
			m = "Metal",
			f = 0.2,
		},
		{
			s = "Cyl",
			z = { 0.62, 0.06, 0.62 },
			p = { 0, 0.88, 0 },
			c = BRASS,
			m = "Metal",
			f = 0.2,
		},
		{ s = "Ball", z = { 0.14, 0.14, 0.14 }, p = { 0, 0.96, 0 }, c = IRON, m = "Metal" },
	},
	-- La batte d'avant usage : du bois clair, le manche entoure de tissu.
	bat = {
		{
			s = "Cyl",
			z = { 0.28, 1.6, 0.28 },
			p = { 0, 0.45, 0 },
			c = { 40, 30, 28 },
			m = "Fabric",
		},
		{ s = "Ball", z = { 0.42, 0.42, 0.42 }, p = { 0, -0.35, 0 }, c = { 40, 30, 28 } },
		{ s = "Cyl", z = { 0.38, 1, 0.38 }, p = { 0, 1.75, 0 }, c = { 200, 160, 110 }, m = "Wood" },
		{
			s = "Cyl",
			z = { 0.52, 1.7, 0.52 },
			p = { 0, 3.1, 0 },
			c = { 200, 160, 110 },
			m = "Wood",
		},
	},
	-- Un piege a loup : socle rond rouille, machoires dentees ouvertes.
	trap = {
		{
			s = "Cyl",
			z = { 0.9, 0.08, 0.9 },
			p = { 0, 0.3, 0 },
			r = { 90, 0, 0 },
			c = RUST,
			m = "CorrodedMetal",
		},
		{
			s = "Cyl",
			z = { 0.25, 0.1, 0.25 },
			p = { 0, 0.3, -0.05 },
			r = { 90, 0, 0 },
			c = IRON,
			m = "Metal",
		},
		{
			s = "Block",
			z = { 0.9, 0.06, 0.06 },
			p = { 0, 0.75, -0.05 },
			c = RUST,
			m = "CorrodedMetal",
		},
		{
			s = "Block",
			z = { 0.9, 0.06, 0.06 },
			p = { 0, -0.15, -0.05 },
			c = RUST,
			m = "CorrodedMetal",
		},
		{
			s = "Wedge",
			z = { 0.04, 0.16, 0.1 },
			p = { -0.3, 0.66, -0.05 },
			r = { 0, 90, 180 },
			c = STEEL,
			m = "Metal",
		},
		{
			s = "Wedge",
			z = { 0.04, 0.16, 0.1 },
			p = { 0, 0.66, -0.05 },
			r = { 0, 90, 180 },
			c = STEEL,
			m = "Metal",
		},
		{
			s = "Wedge",
			z = { 0.04, 0.16, 0.1 },
			p = { 0.3, 0.66, -0.05 },
			r = { 0, 90, 180 },
			c = STEEL,
			m = "Metal",
		},
		{
			s = "Wedge",
			z = { 0.04, 0.16, 0.1 },
			p = { -0.3, -0.06, -0.05 },
			r = { 0, 90, 0 },
			c = STEEL,
			m = "Metal",
		},
		{
			s = "Wedge",
			z = { 0.04, 0.16, 0.1 },
			p = { 0, -0.06, -0.05 },
			r = { 0, 90, 0 },
			c = STEEL,
			m = "Metal",
		},
		{
			s = "Wedge",
			z = { 0.04, 0.16, 0.1 },
			p = { 0.3, -0.06, -0.05 },
			r = { 0, 90, 0 },
			c = STEEL,
			m = "Metal",
		},
	},
	-- Des jumelles : deux tubes noirs, un pont, des verres bleutes.
	binoculars = {
		{
			s = "Cyl",
			z = { 0.3, 0.6, 0.3 },
			p = { -0.2, 0.2, -0.1 },
			r = { 90, 0, 0 },
			c = IRON,
			m = "Metal",
		},
		{
			s = "Cyl",
			z = { 0.3, 0.6, 0.3 },
			p = { 0.2, 0.2, -0.1 },
			r = { 90, 0, 0 },
			c = IRON,
			m = "Metal",
		},
		{
			s = "Block",
			z = { 0.2, 0.12, 0.3 },
			p = { 0, 0.25, -0.1 },
			c = { 30, 30, 32 },
			m = "Metal",
		},
		{
			s = "Cyl",
			z = { 0.26, 0.03, 0.26 },
			p = { -0.2, 0.2, -0.41 },
			r = { 90, 0, 0 },
			c = { 120, 170, 220 },
			m = "Glass",
			f = 0.4,
		},
		{
			s = "Cyl",
			z = { 0.26, 0.03, 0.26 },
			p = { 0.2, 0.2, -0.41 },
			r = { 90, 0, 0 },
			c = { 120, 170, 220 },
			m = "Glass",
			f = 0.4,
		},
		{
			s = "Cyl",
			z = { 0.33, 0.12, 0.33 },
			p = { -0.2, 0.2, 0.18 },
			r = { 90, 0, 0 },
			c = { 20, 20, 20 },
			m = "Fabric",
		},
		{
			s = "Cyl",
			z = { 0.33, 0.12, 0.33 },
			p = { 0.2, 0.2, 0.18 },
			r = { 90, 0, 0 },
			c = { 20, 20, 20 },
			m = "Fabric",
		},
	},
	-- Trois planches clouees, tenues sur le cote.
	planks = {
		{ s = "Block", z = { 0.12, 1.7, 0.36 }, p = { 0, 0.5, -0.38 }, c = WOOD, m = "WoodPlanks" },
		{
			s = "Block",
			z = { 0.12, 1.6, 0.36 },
			p = { 0, 0.45, 0 },
			r = { 0, 0, 4 },
			c = DARKWOOD,
			m = "WoodPlanks",
		},
		{
			s = "Block",
			z = { 0.12, 1.75, 0.36 },
			p = { 0, 0.52, 0.38 },
			r = { 0, 0, -3 },
			c = WOOD,
			m = "WoodPlanks",
		},
		{ s = "Block", z = { 0.16, 0.2, 1.15 }, p = { 0, 1.05, 0 }, c = DARKWOOD, m = "Wood" },
		{
			s = "Cyl",
			z = { 0.05, 0.2, 0.05 },
			p = { 0.08, 1.05, -0.38 },
			r = { 0, 0, 90 },
			c = STEEL,
			m = "Metal",
		},
		{
			s = "Cyl",
			z = { 0.05, 0.2, 0.05 },
			p = { 0.08, 1.05, 0.38 },
			r = { 0, 0, 90 },
			c = STEEL,
			m = "Metal",
		},
	},
	-- Un carton ferme au scotch, un peu ecrase.
	fakeBox = {
		{
			s = "Block",
			z = { 1, 0.8, 0.9 },
			p = { 0, 0.3, -0.3 },
			r = { 0, 0, 3 },
			c = CARDBOARD,
			m = "Cardboard",
		},
		{
			s = "Block",
			z = { 0.22, 0.02, 0.92 },
			p = { 0, 0.71, -0.3 },
			r = { 0, 0, 3 },
			c = { 200, 180, 140 },
			m = "SmoothPlastic",
			t = 0.2,
		},
		{
			s = "Block",
			z = { 0.5, 0.25, 0.02 },
			p = { 0.1, 0.35, -0.76 },
			c = BLOOD,
			m = "SmoothPlastic",
		},
	},
	-- Une boule puante : verre trouble vert, bouchon, une lueur malsaine.
	stinkBomb = {
		{
			s = "Ball",
			z = { 0.55, 0.55, 0.55 },
			p = { 0, 0.3, 0 },
			c = { 140, 170, 40 },
			m = "Glass",
			t = 0.3,
		},
		{
			s = "Ball",
			z = { 0.38, 0.38, 0.38 },
			p = { 0, 0.28, 0 },
			c = { 170, 210, 30 },
			m = "Neon",
			t = 0.3,
			l = { 5, 0.6 },
		},
		{
			s = "Cyl",
			z = { 0.16, 0.2, 0.16 },
			p = { 0, 0.62, 0 },
			c = { 150, 110, 70 },
			m = "Wood",
		},
	},
	-- Un filet roule : paquet de corde, plombs de lest tout autour.
	net = {
		{
			s = "Egg",
			z = { 0.75, 0.55, 0.6 },
			p = { 0, 0.32, 0 },
			c = { 120, 100, 70 },
			m = "Fabric",
		},
		{
			s = "Cyl",
			z = { 0.62, 0.06, 0.62 },
			p = { 0, 0.32, 0 },
			r = { 0, 0, 90 },
			c = { 90, 74, 50 },
			m = "Fabric",
		},
		{ s = "Ball", z = { 0.14, 0.14, 0.14 }, p = { 0.36, 0.2, 0.1 }, c = IRON, m = "Metal" },
		{ s = "Ball", z = { 0.14, 0.14, 0.14 }, p = { -0.36, 0.2, -0.1 }, c = IRON, m = "Metal" },
		{ s = "Ball", z = { 0.14, 0.14, 0.14 }, p = { 0.1, 0.55, -0.28 }, c = IRON, m = "Metal" },
		{ s = "Ball", z = { 0.14, 0.14, 0.14 }, p = { -0.1, 0.1, 0.3 }, c = IRON, m = "Metal" },
	},
	-- Une cape d'ombre pliee, fermoir d'or, liseré de braise.
	cloak = {
		{ s = "Block", z = { 0.75, 0.22, 0.6 }, p = { 0, 0.18, -0.1 }, c = CLOTH, m = "Fabric" },
		{
			s = "Block",
			z = { 0.7, 0.2, 0.55 },
			p = { 0, 0.38, -0.1 },
			r = { 0, 8, 0 },
			c = { 40, 30, 46 },
			m = "Fabric",
		},
		{ s = "Block", z = { 0.76, 0.03, 0.04 }, p = { 0, 0.3, -0.4 }, c = EMBER, m = "Neon" },
		{
			s = "Cyl",
			z = { 0.18, 0.05, 0.18 },
			p = { 0, 0.5, -0.1 },
			c = BRASS,
			m = "Metal",
			f = 0.2,
		},
	},
	-- Un cadenas : corps d'or, anse d'acier.
	padlock = {
		{
			s = "Block",
			z = { 0.5, 0.42, 0.24 },
			p = { 0, 0.25, 0 },
			c = BRASS,
			m = "Metal",
			f = 0.15,
		},
		{ s = "Cyl", z = { 0.07, 0.36, 0.07 }, p = { -0.16, 0.62, 0 }, c = STEEL, m = "Metal" },
		{ s = "Cyl", z = { 0.07, 0.36, 0.07 }, p = { 0.16, 0.62, 0 }, c = STEEL, m = "Metal" },
		{
			s = "Cyl",
			z = { 0.07, 0.36, 0.07 },
			p = { 0, 0.8, 0 },
			r = { 0, 0, 90 },
			c = STEEL,
			m = "Metal",
		},
		{
			s = "Cyl",
			z = { 0.1, 0.03, 0.1 },
			p = { 0, 0.2, -0.13 },
			r = { 90, 0, 0 },
			c = { 20, 20, 20 },
		},
	},
	-- Un miroir a main : cadre de laiton, verre qui renvoie le ciel.
	mirror = {
		{ s = "Cyl", z = { 0.14, 0.55, 0.14 }, p = { 0, 0.1, 0 }, c = DARKWOOD, m = "Wood" },
		{
			s = "Cyl",
			z = { 0.8, 0.08, 0.8 },
			p = { 0, 0.75, 0 },
			r = { 90, 0, 0 },
			c = BRASS,
			m = "Metal",
		},
		{
			s = "Cyl",
			z = { 0.68, 0.03, 0.68 },
			p = { 0, 0.75, -0.05 },
			r = { 90, 0, 0 },
			c = { 220, 230, 240 },
			m = "Glass",
			f = 0.8,
		},
	},
	-- Un grappin : tige d'acier, trois crochets, corde enroulee.
	grapple = {
		{ s = "Cyl", z = { 0.15, 0.7, 0.15 }, p = { 0, 0.4, 0 }, c = STEEL, m = "Metal" },
		{
			s = "Block",
			z = { 0.07, 0.4, 0.07 },
			p = { 0.15, 0.85, 0 },
			r = { 0, 0, -40 },
			c = STEEL,
			m = "Metal",
		},
		{
			s = "Block",
			z = { 0.07, 0.4, 0.07 },
			p = { -0.08, 0.85, 0.13 },
			r = { -35, 0, 20 },
			c = STEEL,
			m = "Metal",
		},
		{
			s = "Block",
			z = { 0.07, 0.4, 0.07 },
			p = { -0.08, 0.85, -0.13 },
			r = { 35, 0, 20 },
			c = STEEL,
			m = "Metal",
		},
		{
			s = "Cyl",
			z = { 0.45, 0.25, 0.45 },
			p = { 0, -0.05, 0 },
			c = { 150, 120, 80 },
			m = "Fabric",
		},
	},
	-- Une seringue d'adrenaline : cylindre de verre, liquide rouge vif.
	adrenaline = {
		{ s = "Cyl", z = { 0.2, 0.6, 0.2 }, p = { 0, 0.3, 0 }, c = GLASS, m = "Glass", t = 0.5 },
		{
			s = "Cyl",
			z = { 0.15, 0.48, 0.15 },
			p = { 0, 0.27, 0 },
			c = BLOOD,
			m = "Neon",
			l = { 4, 0.6 },
		},
		{ s = "Cyl", z = { 0.03, 0.35, 0.03 }, p = { 0, 0.77, 0 }, c = STEEL, m = "Metal" },
		{ s = "Cyl", z = { 0.06, 0.25, 0.06 }, p = { 0, -0.1, 0 }, c = STEEL, m = "Metal" },
		{ s = "Cyl", z = { 0.28, 0.04, 0.28 }, p = { 0, -0.23, 0 }, c = STEEL, m = "Metal" },
	},
	-- Une bache de plomb pliee : gris lourd, coins renforces.
	leadSheet = {
		{
			s = "Block",
			z = { 0.9, 0.3, 0.7 },
			p = { 0, 0.25, -0.1 },
			c = { 90, 92, 98 },
			m = "DiamondPlate",
		},
		{
			s = "Block",
			z = { 0.85, 0.06, 0.65 },
			p = { 0, 0.43, -0.1 },
			r = { 0, 4, 0 },
			c = { 110, 112, 118 },
			m = "Metal",
		},
		{ s = "Block", z = { 0.12, 0.32, 0.12 }, p = { 0.4, 0.25, -0.4 }, c = BRASS, m = "Metal" },
		{ s = "Block", z = { 0.12, 0.32, 0.12 }, p = { -0.4, 0.25, 0.2 }, c = BRASS, m = "Metal" },
	},
	-- Un petit mannequin de bois articule (pose, il grandit a taille d'homme).
	dummy = {
		{
			s = "Egg",
			z = { 0.32, 0.5, 0.2 },
			p = { 0, 0.55, 0 },
			c = { 196, 160, 120 },
			m = "Wood",
		},
		{
			s = "Ball",
			z = { 0.22, 0.22, 0.22 },
			p = { 0, 0.92, 0 },
			c = { 196, 160, 120 },
			m = "Wood",
		},
		{
			s = "Cyl",
			z = { 0.07, 0.36, 0.07 },
			p = { -0.2, 0.52, 0 },
			r = { 0, 0, -12 },
			c = { 196, 160, 120 },
			m = "Wood",
		},
		{
			s = "Cyl",
			z = { 0.07, 0.36, 0.07 },
			p = { 0.2, 0.52, 0 },
			r = { 0, 0, 12 },
			c = { 196, 160, 120 },
			m = "Wood",
		},
		{
			s = "Cyl",
			z = { 0.08, 0.4, 0.08 },
			p = { -0.08, 0.15, 0 },
			c = { 196, 160, 120 },
			m = "Wood",
		},
		{
			s = "Cyl",
			z = { 0.08, 0.4, 0.08 },
			p = { 0.08, 0.15, 0 },
			c = { 196, 160, 120 },
			m = "Wood",
		},
		{ s = "Cyl", z = { 0.06, 0.3, 0.06 }, p = { 0, -0.15, 0 }, c = IRON, m = "Metal" },
	},
	-- Un oeil de verre : globe blanc, iris de braise, pupille noire.
	glassEye = {
		{
			s = "Ball",
			z = { 0.5, 0.5, 0.5 },
			p = { 0, 0.3, 0 },
			c = BONE,
			m = "Glass",
			t = 0.1,
			f = 0.2,
		},
		{
			s = "Cyl",
			z = { 0.28, 0.04, 0.28 },
			p = { 0, 0.3, -0.24 },
			r = { 90, 0, 0 },
			c = EMBER,
			m = "Neon",
			l = { 5, 0.8 },
		},
		{
			s = "Cyl",
			z = { 0.12, 0.05, 0.12 },
			p = { 0, 0.3, -0.26 },
			r = { 90, 0, 0 },
			c = { 10, 6, 6 },
		},
	},
	-- La fusee rouge : plus grosse, la tete qui couve deja.
	redFlare = {
		{
			s = "Cyl",
			z = { 0.34, 1.2, 0.34 },
			p = { 0, 0.25, 0 },
			c = { 170, 16, 16 },
			m = "SmoothPlastic",
		},
		{ s = "Cyl", z = { 0.36, 0.12, 0.36 }, p = { 0, 0.88, 0 }, c = IRON, m = "Metal" },
		{
			s = "Ball",
			z = { 0.3, 0.3, 0.3 },
			p = { 0, 0.98, 0 },
			c = { 255, 40, 30 },
			m = "Neon",
			l = { 6, 1.2 },
		},
		{ s = "Cyl", z = { 0.36, 0.1, 0.36 }, p = { 0, -0.3, 0 }, c = BRASS, m = "Metal" },
	},
	-- Le Regard vole : un eclat de son oeil dans une cage de fer.
	stolenGaze = {
		{
			s = "Ball",
			z = { 0.5, 0.5, 0.5 },
			p = { 0, 0.45, 0 },
			c = { 255, 30, 20 },
			m = "Neon",
			l = { 8, 1.5 },
		},
		{
			s = "Ball",
			z = { 0.62, 0.62, 0.62 },
			p = { 0, 0.45, 0 },
			c = { 60, 0, 0 },
			m = "Glass",
			t = 0.55,
		},
		{ s = "Block", z = { 0.05, 0.75, 0.05 }, p = { 0.33, 0.45, 0 }, c = IRON, m = "Metal" },
		{ s = "Block", z = { 0.05, 0.75, 0.05 }, p = { -0.33, 0.45, 0 }, c = IRON, m = "Metal" },
		{ s = "Block", z = { 0.05, 0.75, 0.05 }, p = { 0, 0.45, 0.33 }, c = IRON, m = "Metal" },
		{ s = "Block", z = { 0.05, 0.75, 0.05 }, p = { 0, 0.45, -0.33 }, c = IRON, m = "Metal" },
		{ s = "Cyl", z = { 0.4, 0.1, 0.4 }, p = { 0, 0.05, 0 }, c = IRON, m = "Metal" },
	},
	-- La Larme de l'Oeil : une goutte d'eau pale qui luit.
	tear = {
		{
			s = "Ball",
			z = { 0.5, 0.5, 0.5 },
			p = { 0, 0.3, 0 },
			c = { 150, 210, 255 },
			m = "Glass",
			t = 0.35,
		},
		{
			s = "Block",
			z = { 0.25, 0.25, 0.25 },
			p = { 0, 0.58, 0 },
			r = { 45, 0, 45 },
			c = { 150, 210, 255 },
			m = "Glass",
			t = 0.35,
		},
		{
			s = "Ball",
			z = { 0.25, 0.25, 0.25 },
			p = { 0, 0.3, 0 },
			c = { 200, 240, 255 },
			m = "Neon",
			l = { 6, 1 },
		},
	},
	-- Le Cocon de secours : une cosse de soie pale, veinee de braise.
	cocoon = {
		{
			s = "Egg",
			z = { 0.45, 0.75, 0.45 },
			p = { 0, 0.35, 0 },
			c = { 225, 215, 200 },
			m = "Fabric",
		},
		{ s = "Egg", z = { 0.47, 0.5, 0.47 }, p = { 0, 0.35, 0 }, c = EMBER, m = "Neon", t = 0.75 },
		{
			s = "Cyl",
			z = { 0.04, 0.3, 0.04 },
			p = { 0, 0.82, 0 },
			c = { 225, 215, 200 },
			m = "Fabric",
		},
	},
	-- Le Fragment de Fissure : un eclat noir, une braise au coeur.
	fragment = {
		{
			s = "Wedge",
			z = { 0.2, 0.7, 0.35 },
			p = { 0, 0.4, 0 },
			r = { 0, 0, 8 },
			c = { 18, 12, 14 },
			m = "Glass",
			f = 0.3,
		},
		{
			s = "Wedge",
			z = { 0.18, 0.5, 0.3 },
			p = { 0.06, 0.35, 0.05 },
			r = { 0, 180, -12 },
			c = { 18, 12, 14 },
			m = "Glass",
			f = 0.3,
		},
		{
			s = "Block",
			z = { 0.06, 0.45, 0.06 },
			p = { 0.02, 0.38, 0 },
			r = { 0, 0, 6 },
			c = EMBER,
			m = "Neon",
			l = { 5, 1 },
		},
	},
}

return shapes
