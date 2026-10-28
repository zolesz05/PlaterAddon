Moteve Plates 0.2.4 – WoW Forever / Interface 16001

Önálló névtábla-addon három váltható skinnel és szerepkörfüggő aggrojelzéssel.
A három előzetes látványterv alapján készült. A Plater telepítése nem szükséges.
A Threat Plates-jellegű működés saját megvalósítás, külső addon kódja nélkül.

TELEPÍTÉS
  A ZIP MotevePlates mappáját másold a játék Interface/AddOns mappájába.
  Új addon hozzáadása után indítsd újra a klienst, ha /reload után nem jelenik meg az addonlistában.
  A karakterválasztón engedélyezd a Moteve Plates addont.
  Az ellenséges névtáblákat a játék V gombjával vagy az addon beállításaiban kapcsolhatod be.

BEÁLLÍTÁSOK
  Options / AddOns / Moteve Plates, vagy /mp.
  A három előnézeti kártya kattintható; a kiválasztott skin azonnal érvényes.
    Minimal: vékony, világos keret, sötét háttér, egyszerű betűk.
    Classic: bronzszegély, texturált sáv, klasszikus címbetű.
    Moteve: sötétkék alap, lila szegély, cián célpontjelzés és visszafogott fény.
  Alapértelmezett skin: Moteve.
  Látótáv (yd): 5–100 yard között kérhető, 5 yardos lépésekben; a kliens saját korlátja érvényes.
  Alatta a játékból visszaolvasott nameplateMaxDistance érték látható, eltérés esetén jelzéssel.
  A szerver ennél rövidebb tényleges megjelenítési távolságot is előírhat.
  Első frissítéskor a meglévő kliensbeállítást veszi át. Utána a mentett értéket alkalmazza belépéskor.
  Harc közben a módosítást elhalasztja a harc végéig. Ez a játék közös névtábla-beállítása.
  A skin, a szerepkör, a méret és a kapcsolók a MotevePlatesDB változóban megmaradnak.

AGGRO
  Harcban a szín a választott szerepkör szerint változik.
  Tank módban:
    Zöld: rajtad az aggro; ha a kliens biztosnak jelzi, STABIL AGGRO.
    Sárga: rajtad van, de bizonytalan – INOG AZ AGGRO.
    Piros: másra került – ELVESZTETT AGGRO.
  DPS / healer módban:
    Zöld: az ellenfél másra figyel – AGGRO MÁSON.
    Sárga: magas fenyegetettség – MAGAS AGGRO.
    Piros: rád fordult – TÉGED TÁMAD.
  Harcon kívül az ellenséges mob sávja piros, a semleges (magától nem támadó) mobé sárga.
  Kikapcsolt aggro-színezésnél is a mob reakciójának megfelelő alapszín látszik.
  Harc közben az engedélyezett tank/DPS aggrojelzés elsőbbséget kap.
  A más által lefoglalt ellenfél szürke;
  ha téged támad, az aggrojelzés akkor is elsőbbséget kap.
  A szöveg, a százalék és a sáv színezése egymástól függetlenül kapcsolható.
  A szöveges jelzés (TÉGED TÁMAD, MAGAS AGGRO stb.) új telepítésnél alapból ki van kapcsolva;
  az "Aggro szöveges jelzése" kapcsolóval kapcsolható be. Meglévő telepítésnél a mentett érték marad.
  Az Alapbeállítások gomb ezt is kikapcsolja, a többi beállítással együtt.
  A százalék a kliens által szolgáltatott, skálázott fenyegetettségi érték.
  A DPS figyelmeztetési küszöb alapértéke 85%; 50–95% között állítható.
  Automatikus módban a játék szerepköre, majd az elérhető specializáció alapján választ.
  Ha nincs használható tankjelzés, DPS/healer módot használ. Klasszikus talenteknél válaszd kézzel a Tank módot.
  Ha a kliens elrejti a fenyegetettségi adatokat és a célpontból sem állapítható meg az állapot,
  az addon AGGRO: ? jelzést mutat. A védett adatokból nem következtet találgatással biztonságos állapotra.

DOT-ELŐREJELZÉS
  Alapból kikapcsolva; a /mp panelen a "DoT-sebzés előrejelzése" kapcsolóval kapcsolható be.
  Minden ellenséges névtábla életerősávján csíkos jelölő takarja azt a részt, amennyit a saját
  DoT-jaid még sebezni fognak. Ha az életerősáv vége a jelölőn belül van, a mob újabb cast nélkül is meghal.
  A jelölő a sáv bal szélénél levágódik, ha a DoT-ok többet sebeznének a hátralévő életerőnél.
  A jelölő színe a kapcsoló melletti "DoT-szín" négyzetekkel választható: "Skin szerint" (alapérték;
  Minimal fehér, Classic lila, Moteve rózsaszín), fehér, lila, rózsaszín, zöld, sárga, türkiz vagy piros.
  A választás mentődik, azonnal látszik a névtáblákon és az előnézeten; az Alapbeállítások visszaállítja.
  Forrás: saját castok (UNIT_SPELLCAST_SENT/SUCCEEDED), varázslatleírások (angol és magyar kliensen)
  és UNIT_COMBAT sebzések. Az első tickek után a valódi tickméretet tanulja meg és menti.
  Az addon nem hasonlítja össze és nem számol a védett életerőértékekkel: a maximális életerőt és
  a becsült sebzést egy StatusBar kapja meg, a kirajzolást a kliens végzi. Combat logot nem olvas; a saját
  debuffjaidat csak azért nézi, hogy a DoT felkerült-e.
  Követett DoT-ok: Warlock (Corruption, Curse/Bane of Agony, Immolate, Siphon Life), Priest (Shadow Word: Pain,
  Devouring Plague), Druid (Moonfire, Insect Swarm, Rake, Rip), Rogue (Rupture, Garrote), Hunter (Serpent Sting),
  Mage (Fireball és Pyroblast DoT-része), Shaman (Flame Shock), Warrior (Rend).
  Korlátok:
    Csak a saját DoT-jaidat követi, és csak a kijelölt célpontra küldött castokat (mouseover/focus nem).
    Cast nélküli DoT-okat (Deep Wounds, Ignite, mérgek) és a mob gyógyulását nem számolja.
    Ha a kliens nem adja meg a kombópontokat, a Rip és a Rupture a legkisebb kombópontszámmal számol.
    Más játékos összetéveszthető, azonos iskolájú sebzésénél a jelölő eltűnik, amíg a tickek újra egyértelműek.
    A jelölő csak a saját debuff megjelenése vagy az első tick után számol a DoT-tal, így a resistelt,
    missed vagy immune DoT egy pillanatra sem látszik. Ha a debuff lekerül (pl. dispel), a DoT azonnal kiesik.
    Közvetlenül a cast utáni miss/dodge/parry/resist/immune, illetve két elmaradt tick eldobja a DoT-ot.
    Más nyelvű kliensen a leírást nem olvassa; ott az első tick után jelenik meg a jelölő.
  A tanult tickméreteket a /mp dotreset törli.
  A követés logikája a DoesItDie addon (https://github.com/swirllyman/DoesItDie, MIT-licenc,
  Copyright (c) 2026 Joe Greive) megközelítésén alapul; licence: LICENSE-DoesItDie.txt.

TOVÁBBI KIJELZÉSEK
  Küldetésmobok: apró, tompa arany ! a név előtt, háttér és felirat nélkül; a név eredeti színével.
  A kiemelés a /mp panel alján kapcsolható. Az életerősáv aggro szerinti színe megmarad.
  Felismerés: a játék UnitIsQuestBoss jelzése és opcionálisan a Questie aktív célpontadatai,
  beleértve a küldetéstárgyat dobó mobokat. A Questie nem kötelező függőség.
  Befejezett Questie-célok jelzése eltűnik; a változásokat küldetésesemények és másodpercenkénti frissítés követi.
  Védett vagy hiányzó adatokból az addon nem találgat küldetéskapcsolatot.
  Életerő és százalék, szint / elit jelzés, kétoldali célpontkiemelés.
  A szintszám és az elit + jel a mob nehézségi színét kapja a játékos szintjéhez képest
  (szürke/zöld/sárga/narancs/piros, a kliens GetQuestDifficultyColor színe); „??” (-1) szintű mobnál piros.
  Ha a kliens nem ad színt, vagy a szint védett / nem olvasható, a skin kiemelőszíne marad.
  Cast és channel sáv idővel, varázslatikonnal; a nem szakítható / ismeretlen állapotú sáv szürke.
  Alapból legfeljebb 8 saját debuff ikonnal és az elérhető időzítési adatokkal.
  A /mp panelen a Debuffok száma 1–12 között állítható; 6 ikon után új sorba tördel, felfelé.
  Forever kliensen a Blizzard AuraContainer / CustomAuraButton rendszere kezeli az élő ikonokat,
  a stackeket és a cooldown rajzolatát; az addon nem olvassa ki a védett auraadatokat.
  A hátralévő idő egyetlen számként, az ikonon belül látszik (a cooldown saját visszaszámlálója),
  az ikon alatt nincs külön időszöveg. Ez a szám a játék cooldown-szám beállításától függ
  (Interface beállítások, „cooldown számok mutatása”); ha az ki van kapcsolva, az ikonon nem látszik idő.
  Az aurák a saját névtáblához kapcsolódnak, a gyári UnitFrame elrejtése nem rejti el őket.
  Régebbi kliensen, ha nincs AuraContainer támogatás, a korábbi aura-lekérés marad tartalékmegoldásként;
  ott is csak az ikonon belüli visszaszámláló mutatja az időt.
  Raid target marker, a nem célzott ellenfelek halványítása.
  Méretarány 65–150%, szélesség 140–260, sávmagasság 12–26, függőleges eltolás -30…40.
  A baráti és a saját névtáblákat az addon megtartja. Ellenséges játékosnál nincs NPC-aggroszínezés.
  A kliens által tiltott névtáblákhoz nem nyúl. A saját grafika átengedi az egérkattintást a natív névtáblának.
  Kikapcsoláskor visszaállítja az eredeti névtábla láthatóságát.

PARANCSOK
  /mp                         beállítások
  /mp skin minimal|classic|moteve
  /mp tank                    kézi tank mód
  /mp dps                     kézi DPS/healer mód
  /mp auto                    automatikus szerepkör
  /mp scale 0.85              85%-os méret
  /mp distance 40             névtáblák megjelenítési távolsága (yard)
  /mp on /mp off              addon be / ki
  /mp errors                  az aktuális belépés alatt rögzített hibák
  /mp auras                   saját debuffok kapcsolója és az aktív névtáblák aura-megjelenítője
  /mp dotreset                a DoT-előrejelzés tanult tickméreteinek törlése

ELLENŐRZÉS
  Helyi Lua/WoW-szimulációval tesztelve: a szerepkörök és aggroállapotok, három skin,
  előnézeti gombok, beállítások mentése, HP, cast/channel, saját aurák és régi aura-API,
  célpontjelzés, natív felület visszaállítása, névtábla újrafelhasználása, ismeretlen/védett adatok,
  hiányzó API-k, beállítások javítása és parancsok. A beállítópanel geometriáját külön átnéztem.
  0.1.2: a védett aurákhoz tartozó natív megjelenítő kötései, saját debuff-szűrője,
  ki-/bekapcsolása, névtábla-újrafelhasználása és leválasztása helyi szimulációval ellenőrizve.
  0.2.0: a DoT-logika tesztje: lua tools/test_dots.lua (a repository gyökeréből, Lua 5.1+).
  Leírás-feldolgozás angolul és magyarul nyolc osztályra, finisherek, tickpárosítás, eldobás,
  bizonytalanság, eseményregisztráció és a jelölő elrejtése. A magyar minták élő kliens nélkül készültek.
  0.2.1: a szintszín tesztje: lua tools/test_level_color.lua (nehézségi szín, „??” piros,
  hiányzó / hibás / rossz alakú kliensválasz és védett szint esetén skinszín mindhárom skinre).
  0.2.2: a debuff-idő tesztje: lua tools/test_aura_timer.lua (a tartalék és a natív ikonokon
  nincs ikon alatti időszöveg, a cooldown visszaszámlálója nincs elrejtve, a natív gomb cooldownt kap).
  0.2.3: a DoT-szín tesztje: lua tools/test_dot_color.lua (skin szerinti és palettaszín, hibás választás
  és ismeretlen skin, a jelölő három rétegének színe, a mentett érték ellenőrzése betöltéskor és beállításkor).
  0.2.4: a DoT-teszt (lua tools/test_dots.lua) a megerősítetlen, resistelt DoT rejtését, a saját debuff
  beolvasását (spellId és név szerint, védett adatnál semmi), a dispel utáni azonnali eldobást és a
  UNIT_AURA regisztrálását is ellenőrzi.
  A tényleges WoW Forever kliensben a megjelenést és a harci állapotokat még ellenőrizni kell.

BETŰTÍPUSOK
  Barlow és Marcellus, SIL Open Font License. A licencek a Fonts mappában találhatók.
  A grafika natív WoW-textúrákból és az addon által rajzolt elemekből áll.

API-HIVATKOZÁSOK
  Blizzard API-leírások és UI-forrás:
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleStatusBarAPIDocumentation.lua
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.lua
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/CVarDocumentation.lua
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua
  https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua
