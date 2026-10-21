# Moteve Plates

**Moteve Plates** egy önálló World of Warcraft névtábla-addon a WoW Forever klienshez. Az ellenfelek fölött megjelenő névtáblákon életerőt, varázslást, saját debuffokat és szerepkörfüggő aggrojelzést mutat.

**Aktuális verzió: 0.1.6**

[Legfrissebb addon letöltése (ZIP)](downloads/MotevePlates.zip?raw=true)

A `downloads` mappában csak a legfrissebb telepíthető `MotevePlates.zip` marad. Frissítéskor ugyanaz a letöltési link használható.

## Telepítés

1. Töltsd le és csomagold ki a fenti ZIP-et.
2. Másold a `MotevePlates` mappát a játék `Interface/AddOns/` könyvtárába.
3. A karakterválasztón engedélyezd a **Moteve Plates** addont, majd lépj be.
4. A beállításokat a `/mp` paranccsal nyithatod meg. Az ellenséges névtáblákat a játék `V` gombjával kapcsolhatod be.

```text
Interface/
└── AddOns/
    └── MotevePlates/
        ├── MotevePlates.toc
        ├── Core.lua
        ├── Plates.lua
        └── Fonts/
```

A mappanevet tartsd meg; ne kerüljön még egy almappa a `MotevePlates.toc` és a `MotevePlates` közé. Új addon telepítése után indítsd újra a klienst, ha a listában még nem jelenik meg. Meglévő addon frissítése után `/reload` használható. A `WTF` könyvtárban tárolt beállításokat tartsd meg.

## Funkciók

- Három azonnal váltható névtáblakinézet: **Minimal, Classic, Moteve**.
- Életerő és százalék, szint / elit jelzés, célpontkiemelés és raid marker.
- Tank és DPS/healer szerepkör szerint működő aggrojelzés, külön kapcsolható szöveggel, százalékkal és sávszínezéssel.
- Cast és channel sáv varázslatikonnal és idővel.
- Saját debuffok és DoT-ok ikonnal, elérhető időzítéssel és stackjelzéssel.
- Alapból legfeljebb **8 debuff**; a darabszám **1–12 között állítható**, hat ikon után új sorral.
- Küldetésmobok előtt apró, tompa arany **!**, nagy felirat vagy külön háttér nélkül.
- Állítható névtábla-távolság, méret, szélesség, sávmagasság és függőleges eltolás.
- A nem célzott ellenfelek halványítása, a baráti és saját névtáblák megtartása.

## Kinézetek

| Stílus | Megjelenés |
| --- | --- |
| Minimal | Vékony világos keret, sötét háttér, egyszerű betűk |
| Classic | Bronzszegély, texturált életerősáv, klasszikus címbetű |
| Moteve | Sötétkék felület, lila szegély és cián célpontjelzés |

Az alapértelmezett a **Moteve**. A `/mp` panelen a kinézetek előnézeti kártyái kattinthatók, a választást megjegyzi.

## Aggrojelzés

| Szín | Tank módban | DPS / healer módban |
| --- | --- | --- |
| Zöld | Rajtad az aggro | Az ellenfél másra figyel |
| Sárga | Bizonytalan aggro | Magas fenyegetettség |
| Piros | Másra került az aggro | Téged támad |

Automatikus módban a játék által jelzett szerepkörből vagy az elérhető specializációból választ. Ha a kliens nem ad használható tankjelzést, válaszd kézzel a **Tank** módot. A DPS figyelmeztetés küszöbe alapból 85%, és 50–95% között állítható.

Harcon kívül az ellenséges mobok sávja **piros**, a semleges, maguktól nem támadó moboké **sárga**. Kikapcsolt aggro-színezésnél is ez a reakció szerinti alapszín marad. Harc közben az engedélyezett tank/DPS aggrojelzés elsőbbséget kap. Hiányzó vagy védett fenyegetettségi adat esetén az addon ismeretlen állapotot jelezhet; a fenyegetettségi százalékot a kliens szolgáltatja. Ez saját megvalósítású, Threat Plates-jellegű működés.

## Távolság és debuffok

A névtáblák kívánt megjelenítési távolsága **5–100 yard** között kérhető. A panel a kliensből visszaolvasott értéket is megmutatja. A játék vagy a szerver alacsonyabb korlátot szabhat; az addon ezen nem tud túllépni. Harc közben a módosítás a harc végéig vár.

A debuffokhoz a Forever kliens natív aura-megjelenítőjét használja, ha az elérhető. A hátralévő idő és stackek megjelenése a kliens által biztosított adatoktól függ. A debuffok száma és a saját aurák megjelenítése a `/mp` panelen állítható.

## Parancsok

| Parancs | Művelet |
| --- | --- |
| `/mp` | Beállítások megnyitása |
| `/mp skin minimal` | Minimal kinézet |
| `/mp skin classic` | Classic kinézet |
| `/mp skin moteve` | Moteve kinézet |
| `/mp tank` | Kézi tank mód |
| `/mp dps` | Kézi DPS / healer mód |
| `/mp auto` | Automatikus szerepkör |
| `/mp scale 0.85` | 85%-os méret |
| `/mp distance 40` | Kívánt megjelenítési távolság: 40 yard |
| `/mp on` / `/mp off` | Addon be- és kikapcsolása |
| `/mp auras` | Saját debuffok állapotának és az aktív aura-megjelenítőknek a kiírása |
| `/mp errors` | Az aktuális belépés alatt rögzített hibák kiírása |

## Kompatibilitás

A célkliens **WoW Forever**, a TOC Interface-értéke **16001**. A beállítások a `MotevePlatesDB` változóban maradnak meg.

**A Plater telepítése nem szükséges.** A repository neve PlaterAddon, de az addon neve és telepítési mappája **MotevePlates**. A Questie opcionális: aktív küldetéscél-adataival segítheti a küldetésmobok felismerését. Más névtábla-addonok egyidejű használata megjelenítési ütközést okozhat.

A 0.1.6-os verzió a semleges mobok sárga névtáblájának javítását tartalmazza. A helyi tesztek mindhárom skint, az aggro-színezés kapcsolóját, a harci állapotokat és a hiányzó/védett reakcióadatokat is ellenőrzik. A korábbi aggro-, aura-, küldetésjelölő- és távolságtesztek is sikeresek. Az élő kliens megjelenítését és harci viselkedését a feltöltéskor nem teszteltük újra.

## Hibajelentés

Hibát az [Issues oldalon](https://github.com/zolesz05/PlaterAddon/issues) jelezhetsz. Add meg a kliens és az addon verzióját, a kiválasztott skint és szerepkört, valamint a reprodukálás lépéseit. A `/mp errors` és `/mp auras` kimenete, illetve egy képernyőkép segíthet.

## Forrás és csomagolás

A teljes addon a [MotevePlates](MotevePlates/) mappában található. A [részletes leírás](MotevePlates/README.txt) a működésről és a kliens korlátairól további információt tartalmaz. A Barlow és Marcellus betűtípusok SIL Open Font License fájljai a `MotevePlates/Fonts/` könyvtárban szerepelnek.

A legfrissebb telepíthető csomag frissítése a repository gyökeréből:

```sh
python tools/package_addon.py
```

A csomagoló ellenőrzi a TOC bejegyzéseit és a ZIP tartalmát, lecseréli a `downloads/MotevePlates.zip` fájlt, és eltávolítja a korábbi verziószámos addoncsomagokat ebből a mappából. A forrást, a ZIP-et és a README-t együtt kell feltölteni.
