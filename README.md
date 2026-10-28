# Moteve Plates

**Moteve Plates** egy önálló World of Warcraft névtábla-addon a WoW Forever klienshez. Az ellenfelek fölött megjelenő névtáblákon életerőt, varázslást, saját debuffokat és szerepkörfüggő aggrojelzést mutat.

**Aktuális verzió: 0.2.4**

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
- Életerő és százalék, szint / elit jelzés, célpontkiemelés és raid marker. A szintszám a mob nehézségi színét kapja (szürke/zöld/sárga/narancs/piros), „??” mobnál piros.
- Tank és DPS/healer szerepkör szerint működő aggrojelzés, külön kapcsolható szöveggel, százalékkal és sávszínezéssel. A szöveges jelzés új telepítésnél alapból ki van kapcsolva.
- Bekapcsolható **DoT-sebzés előrejelzés**: az életerősáv végén jelölő mutatja, mennyit sebeznek még a saját DoT-jaid.
- Cast és channel sáv varázslatikonnal és idővel.
- Saját debuffok és DoT-ok ikonnal, az ikonon belüli visszaszámlálóval és stackjelzéssel.
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

A szöveges aggrojelzés („TÉGED TÁMAD”, „MAGAS AGGRO” stb.) új telepítésnél alapból **ki van kapcsolva**; az **Aggro szöveges jelzése** kapcsolóval kapcsolható be. Meglévő telepítésnél a korábban mentett beállítás marad meg. Az **Alapbeállítások** gomb ezt is kikapcsolja, a többi beállítással együtt.

Automatikus módban a játék által jelzett szerepkörből vagy az elérhető specializációból választ. Ha a kliens nem ad használható tankjelzést, válaszd kézzel a **Tank** módot. A DPS figyelmeztetés küszöbe alapból 85%, és 50–95% között állítható.

Harcon kívül az ellenséges mobok sávja **piros**, a semleges, maguktól nem támadó moboké **sárga**. Kikapcsolt aggro-színezésnél is ez a reakció szerinti alapszín marad. Harc közben az engedélyezett tank/DPS aggrojelzés elsőbbséget kap. Hiányzó vagy védett fenyegetettségi adat esetén az addon ismeretlen állapotot jelezhet; a fenyegetettségi százalékot a kliens szolgáltatja. Ez saját megvalósítású, Threat Plates-jellegű működés.

## DoT-előrejelzés

Alapból kikapcsolva; a `/mp` panelen a **DoT-sebzés előrejelzése** kapcsolóval kapcsolható be. Bekapcsolva minden ellenséges névtábla életerősávján egy csíkos jelölő takarja azt a részt, amennyit a saját DoT-jaid még sebezni fognak. Ha az életerősáv vége a jelölőn belül van, a mob újabb varázslat nélkül is meghal. A jelölő a sáv bal szélénél levágódik, ha a DoT-ok többet sebeznének a hátralévő életerőnél.

A jelölő színe a kapcsoló melletti **DoT-szín** négyzetekkel választható. Az alapértelmezett **Skin szerint** (az „S” jelű négyzet) a skin saját színét használja: Minimal fehér, Classic lila, Moteve rózsaszín. Emellett fehér, lila, rózsaszín, zöld, sárga, türkiz és piros választható; a négyzet fölé víve az egeret megjelenik a szín neve. A zöld, a sárga és a piros világosabb az aggro-színezés árnyalatainál, így a jelölő a színezett sávon is elüt. A választás mentődik, azonnal látszik az élő névtáblákon és a skin-előnézeteken, az **Alapbeállítások** gomb pedig visszaállítja a Skin szerinti színt. Az átlátszóság nem állítható.

Az addon a saját varázslataidból, a varázslatleírásokból (angol és magyar kliensen) és a `UNIT_COMBAT` sebzésekből becsül; az első tickek után a valódi tickméretet tanulja meg és menti. Az életerőt nem hasonlítja össze és nem számol vele: a maximális életerőt és a becsült sebzést egy StatusBar kapja meg, a kirajzolást a kliens végzi. Követett DoT-ok: Warlock (Corruption, Curse/Bane of Agony, Immolate, Siphon Life), Priest (Shadow Word: Pain, Devouring Plague), Druid (Moonfire, Insect Swarm, Rake, Rip), Rogue (Rupture, Garrote), Hunter (Serpent Sting), Mage (Fireball és Pyroblast DoT-része), Shaman (Flame Shock), Warrior (Rend).

Korlátok:

- Csak a saját DoT-jaidat követi, és csak a kijelölt célpontra küldött varázslatokat; mouseover- és focus-castokat nem.
- Cast nélküli DoT-okat (Deep Wounds, Ignite, mérgek) és a mob gyógyulását nem számolja.
- Ha a kliens nem adja meg a kombópontokat, a Rip és a Rupture a legkisebb kombópontszámmal számol, így a becslés alacsonyabb lehet.
- Ha egy másik játékos ugyanolyan iskolájú sebzése összetéveszthető a tickjeiddel, a jelölő eltűnik, amíg a tickek újra egyértelműek. Csoportban ezért ritkábban látszik.
- A jelölő csak akkor számol egy DoT-tal, ha az bizonyíthatóan felkerült: látszik a saját debuffja, vagy beérkezett az első tickje. A resistelt, missed vagy immune DoT így egy pillanatra sem jelenik meg. Ha a saját debuffokat a kliens védett adatként adja, a DoT az első ticktől látszik.
- Ha a DoT debuffja lekerül (dispel vagy más eltávolítás), a DoT azonnal kiesik, és a jelölő frissül.
- Közvetlenül a cast után érkező miss, dodge, parry, resist vagy immune eldobja a DoT-ot, ahogy két elmaradt tick is. Újabb casttal a követés újraindul.
- A tanult tickméreteket a `/mp dotreset` törli.

A követés logikája a [DoesItDie](https://github.com/swirllyman/DoesItDie) addon (MIT-licenc, © 2026 Joe Greive) megközelítésén alapul; a licenc a `MotevePlates/LICENSE-DoesItDie.txt` fájlban található. A DoesItDie kinézetét az addon nem veszi át.

## Távolság és debuffok

A névtáblák kívánt megjelenítési távolsága **5–100 yard** között kérhető. A panel a kliensből visszaolvasott értéket is megmutatja. A játék vagy a szerver alacsonyabb korlátot szabhat; az addon ezen nem tud túllépni. Harc közben a módosítás a harc végéig vár.

A debuffokhoz a Forever kliens natív aura-megjelenítőjét használja, ha az elérhető. A hátralévő idő egyetlen számként, az ikonon belül látszik (a cooldown saját visszaszámlálója), az ikon alatt nincs külön időszöveg. Ez a szám a játék cooldown-szám beállításától függ: ha a „cooldown számok mutatása” ki van kapcsolva, az ikonon nem látszik idő. A hátralévő idő és a stackek megjelenése a kliens által biztosított adatoktól is függ. A debuffok száma és a saját aurák megjelenítése a `/mp` panelen állítható.

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
| `/mp dotreset` | A DoT-előrejelzés tanult tickméreteinek törlése |

## Kompatibilitás

A célkliens **WoW Forever**, a TOC Interface-értéke **16001**. A beállítások a `MotevePlatesDB` változóban maradnak meg.

**A Plater telepítése nem szükséges.** A repository neve PlaterAddon, de az addon neve és telepítési mappája **MotevePlates**. A Questie opcionális: aktív küldetéscél-adataival segítheti a küldetésmobok felismerését. Más névtábla-addonok egyidejű használata megjelenítési ütközést okozhat.

A 0.2.0-s verzió új, alapból kikapcsolt DoT-sebzés előrejelzést hoz, és új telepítésnél alapból kikapcsolja a szöveges aggrojelzést. A `tools/test_dots.lua` helyi tesztjei a leírások angol és magyar feldolgozását mind a nyolc osztályra, a kombópontos finishereket, a tickek iskola, ritmus és méret szerinti párosítását, az eldobási és bizonytalansági szabályokat, valamint az események regisztrálását és a jelölő elrejtését ellenőrzik. Az élő kliens megjelenítését és harci viselkedését a feltöltéskor nem teszteltük; a magyar leírások mintái valódi magyar kliens nélkül készültek.

A 0.2.1-es verzióban a névtábla szintszáma és elit `+` jele a mob nehézségi színét kapja a kliens `GetQuestDifficultyColor` segédjéből; „??” (-1) szintű mobnál piros. Ha a kliens nem ad színt, vagy a szint védett, a skin kiemelőszíne marad. A `tools/test_level_color.lua` ezt helyi stubokkal ellenőrzi; hogy a WoW Forever kliens valóban ad-e nehézségi színt, élő kliensen még nem teszteltük.

A 0.2.2-es verzióban a saját debuff ikonokon a hátralévő idő csak egyszer, az ikonon belüli visszaszámlálóként látszik; az ikon alatti kis időszöveg kikerült, a natív és a tartalék aura-megjelenítőn egyaránt. A `/mp` panel előnézete is futó cooldownt mutat. A belső szám a játék cooldown-szám beállításától függ. A `tools/test_aura_timer.lua` ezt helyi stubokkal ellenőrzi; élő kliensen még nem teszteltük.

A 0.2.3-as verzióban a DoT-előrejelzés jelölőjének színe a `/mp` panelen választható: Skin szerint (alapérték, a korábbi színek) vagy hét előre megadott szín közül. A `tools/test_dot_color.lua` helyi stubokkal ellenőrzi a színfeloldást, a jelölő színezését és a mentett érték ellenőrzését; élő kliensen még nem teszteltük.

A 0.2.4-es verzióban a DoT-előrejelzés jelölője csak a ténylegesen felkerült DoT-okat mutatja: a saját debuff megjelenése vagy az első tick után. Resistnél a jelölő nem villan fel, a dispellelt DoT pedig azonnal kiesik. A `tools/test_dots.lua` helyi stubokkal ellenőrzi a megerősítetlen DoT rejtését, a saját debuffok beolvasását és a dispel utáni eldobást; élő kliensen még nem teszteltük.

## Hibajelentés

Hibát az [Issues oldalon](https://github.com/zolesz05/PlaterAddon/issues) jelezhetsz. Add meg a kliens és az addon verzióját, a kiválasztott skint és szerepkört, valamint a reprodukálás lépéseit. A `/mp errors` és `/mp auras` kimenete, illetve egy képernyőkép segíthet.

## Forrás és csomagolás

A teljes addon a [MotevePlates](MotevePlates/) mappában található. A [részletes leírás](MotevePlates/README.txt) a működésről és a kliens korlátairól további információt tartalmaz. A Barlow és Marcellus betűtípusok SIL Open Font License fájljai a `MotevePlates/Fonts/` könyvtárban szerepelnek. A DoesItDie MIT-licence a `MotevePlates/LICENSE-DoesItDie.txt` fájlban van.

A legfrissebb telepíthető csomag frissítése a repository gyökeréből:

```sh
python tools/package_addon.py
```

A DoT-logika, a szintszín, a debuff-idő és a DoT-szín tesztjei Lua 5.1 vagy újabb értelmezővel futtathatók a repository gyökeréből; hiba esetén nem nulla kóddal lépnek ki:

```sh
lua tools/test_dots.lua
lua tools/test_level_color.lua
lua tools/test_aura_timer.lua
lua tools/test_dot_color.lua
```

A csomagoló ellenőrzi a TOC bejegyzéseit és a ZIP tartalmát, lecseréli a `downloads/MotevePlates.zip` fájlt, és eltávolítja a korábbi verziószámos addoncsomagokat ebből a mappából. A forrást, a ZIP-et és a README-t együtt kell feltölteni.
