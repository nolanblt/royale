# Les images de la page du jeu

Faites le 15 novembre 2026, à partir de vraies captures de la carte dans
Studio : l'Œil, des personnages posés pour la scène, des faisceaux rouges.
Toutes les propositions sont dans `planche-comparaison.png` ; ce qui est
retenu pour le lancement est dans `planche-finale.png`.

## Vignette ou icône ?

- **La vignette** (rectangle 1920 × 1080) : celle qu'on voit sur la page
  d'accueil de Roblox, et qui défile en haut de la page du jeu (jusqu'à 10).
  C'est elle qui fait cliquer.
- **L'icône** (carré 512 × 512) : celle qu'on voit dans la recherche,
  « Découvrir », les favoris et « Continuer ». Elle fait reconnaître le jeu.

## Les trois séries de vignettes

**Un seul style de titre pour toutes** (demandé par Josh le 15 novembre au
soir) : Impact blanc à gros contour noir, un mot clé en jaune, au plus
quatre mots. Chaque titre est posé là où il ne cache ni l'Œil ni ce qui
accroche l'œil : en haut, en bas, ou sur deux lignes dans la bande d'un
côté (`Add-Head` dans `tools/vignettes.ps1`). Les couleurs des captures sont
ravivées (saturation et contraste) à l'assemblage.

Chaque série a une **principale** (la n° 1), faite pour l'accueil, et trois
d'accompagnement pour le diaporama de la page du jeu.

| Série | Style | 1 (principale) | 2 | 3 | 4 |
| --- | --- | --- | --- | --- | --- |
| `serie-1` « la Banlieue » | Banlieue | HIDE FROM THE EYE (un joueur aspiré, un autre caché) | NO SPOT IS SAFE (voiture arrachée) | DON'T GET SEEN (quatre faisceaux vus d'en haut) | HIDE WITH FRIENDS (trois cachés dans des buissons) |
| `serie-2` « toute la carte » | D'autres zones | HIDE OR GET TAKEN (aspiré devant la grande roue) | IT SEES EVERYTHING (l'Œil au-dessus du lycée) | STAY OUT OF SIGHT (deux cachés derrière un wagon) | LAST ONE HIDDEN WINS (le faisceau frôle un joueur devant le chapiteau) |
| `serie-3` « le défi » | Cercles rouges, façon défi | WHO GETS TAKEN? (cinq joueurs alignés, l'Œil en vise un) | CAN YOU SPOT HIM? (un joueur caché dans un buisson, entouré) | 1 LEFT (le dernier, encerclé par quatre faisceaux) | IT'S RIGHT ABOVE YOU (l'Œil juste au-dessus de la rue) |

## La vignette « logo »

`logo/1-logo-hide-from-the-eye.png` : l'Œil de face à droite, le nom du jeu
en grand à gauche. Proposée par Josh, active dès le lancement (une vignette qui
montre le jeu en action fait d'habitude mieux cliquer qu'un logo, mais seul
le test le dira).

## Les trois icônes

| Fichier | Ce qu'elle montre |
| --- | --- |
| `icones/1-oeil.png` | L'Œil de face, iris rouge |
| `icones/2-aspire.png` | Un joueur aspiré vers la pupille |
| `icones/3-cache.png` | Vu par-dessus l'épaule d'un joueur caché dans un buisson, le faisceau tout près |

## Le choix de Josh (15 novembre 2026, soir) — définitif pour le lancement

- **Icône : `icones/1-oeil.png`** (l'Œil de face, zoomé).
- **9 vignettes**, un mélange des trois séries plus le logo.
  - **4 actives sur l'accueil** (Roblox les montre à tour de rôle et garde
    la meilleure) : `serie-3/1-who-gets-taken`,
    `serie-1/1-hide-from-the-eye`, `serie-2/1-hide-or-get-taken`,
    `logo/1-logo-hide-from-the-eye`. Quatre plutôt que trois : le test
    prendra un peu plus de temps, chaque image recevant moins d'affichages.
  - **5 passives**, seulement sur la page du jeu : `serie-1/2-no-spot-is-safe`,
    `serie-3/2-can-you-spot-him`, `serie-2/2-it-sees-everything`,
    `serie-1/4-hide-with-friends`, `serie-2/4-last-one-hidden-wins`.
  - **Page du jeu, dans cet ordre** : who gets taken, hide from the eye,
    hide or get taken, le logo, no spot is safe, can you spot him,
    it sees everything, hide with friends, last one hidden wins.
  - Écartées : `serie-1/3`, `serie-2/3`, `serie-3/3`, `serie-3/4`.
- Mes notes (sur 10, dans leur rôle) : who gets taken 7, hide from the eye
  6,5, hide or get taken 6, logo 6 en active (8 comme image de marque),
  no spot is safe 7,5, can you spot him 6, hide with friends 6, last one
  hidden wins 5,5, it sees everything 5, icône 8. Si « hide or get taken »
  perd le test, la remplacer par « no spot is safe ».

**Vu par Josh dans Creator Hub le 16 novembre 2026** : la personnalisation
(le test gratuit des vignettes actives) est **désactivée tant que le jeu n'a
pas plus de 1000 joueurs par jour de façon régulière**. Au lancement, c'est
donc la **première vignette** de la liste qui se montre : « Who gets taken? »
en premier. Les 4 restent cochées « actives », pour que le test parte tout
seul le jour où le seuil est atteint.

## Comment s'en servir (proposé au départ)

1. Josh choisit la série qu'il préfère : elle va dans le diaporama de la page
   du jeu, sa principale en premier (l'ordre se règle dans Creator Hub).
2. Sur l'accueil (Creator Hub → Places → Thumbnails → onglet **Home Page**),
   mettre en « actives » les **trois principales** : Roblox les montre à tour
   de rôle et garde celle qui fait le plus cliquer (2 à 5 actives,
   gratuit).
3. L'icône : Roblox ne la teste pas tout seul. Josh choisit ; pour comparer
   quand même, en changer à la main une semaine chacune et regarder les
   chiffres.

Roblox conseille de ne rien changer pendant 1 à 2 jours après un changement,
le temps qu'il mesure.

## Les refaire

- **Les scènes** : série 1 et icône 1 par `tools/Vignettes.luau` (scènes A,
  B, C, D, Icone), en mode édition. Les séries 2 et 3 et les icônes 2 et 3
  ont été posées à la main depuis le pont avec les mêmes briques (faisceau,
  personnage, buisson) ; leurs caméras sont notées ci-dessous. Les images
  brutes sont dans `brut/`.
- **L'assemblage** : `tools/vignettes.ps1` (PowerShell, outils d'image de
  Windows) met chaque image en 1920 × 1080, ajoute un fond flouté sur les
  côtés, écrit le titre et trace les cercles.

```powershell
& tools/vignettes.ps1 -Dir docs/vignettes
```

| Brut | Caméra (position → point visé) | Décor posé |
| --- | --- | --- |
| `2A-grande-roue` | (700, 42, 790) → (480, 210, 520) | Faisceau sur (640, 34, 745), joueur ×2,2 sur le faisceau |
| `2B-lycee` | (-40, 32, 760) → (-20, 190, 250) | Faisceau sur (-15, 22, 680), trois joueurs ×1,6 |
| `2C-wagon` | (-262, 8, -792) → (-130, 170, -300) | Faisceau sur (-195, 5, -700), deux joueurs au pied du wagon |
| `2D-chapiteau` | (530, 40, 730) → (330, 180, 470) | Joueur ×1,5 en (492, 34, 690), faisceau juste à sa gauche |
| `3A-trouve` | (556, 50, 592) → (522, 30, 632) | Huit buissons, un joueur dans le troisième, faisceau en (505, 600) |
| `3B-dernier` | (-26, 52, 478) → (-22, 80, 300) | Joueur ×1,4 au milieu du terrain de sport, quatre faisceaux autour |
| `3C-au-dessus` | (472, 17, 66) → (371, 58, 50) | Faisceau sur (410, 12, 52) |
| `3D-ligne` | (474, 16, 61) → (371, 55, 58) | Cinq joueurs en x = 452, faisceau sur celui du milieu |
| `icone2` | (120, 25, 150) → (20, 330, 20) | Joueur ×3 à 70 studs de la caméra vers l'Œil, sans faisceau |
| `icone3` | (709, 41, 776) → (676, 54, 742) | Joueur dans un buisson en (700, 770), regard vers l'Œil |

**Limites** : les personnages sont des avatars de base, debout ou enfoncés
dans un buisson. Je ne peux pas plier leurs bras dans Studio : le corps
moderne n'a plus d'articulations modifiables. Les images viennent de la
fenêtre de Studio (1255 × 1073), agrandies : nettes sur un téléphone,
légèrement douces en plein écran.
