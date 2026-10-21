Moteve Plates 0.1.5 – WoW Forever / Interface 16001

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
  Harcon kívül az ellenséges sáv alapszíne piros. A más által lefoglalt ellenfél szürke;
  ha téged támad, az aggrojelzés akkor is elsőbbséget kap.
  A szöveg, a százalék és a sáv színezése egymástól függetlenül kapcsolható.
  A százalék a kliens által szolgáltatott, skálázott fenyegetettségi érték.
  A DPS figyelmeztetési küszöb alapértéke 85%; 50–95% között állítható.
  Automatikus módban a játék szerepköre, majd az elérhető specializáció alapján választ.
  Ha nincs használható tankjelzés, DPS/healer módot használ. Klasszikus talenteknél válaszd kézzel a Tank módot.
  Ha a kliens elrejti a fenyegetettségi adatokat és a célpontból sem állapítható meg az állapot,
  az addon AGGRO: ? jelzést mutat. A védett adatokból nem következtet találgatással biztonságos állapotra.

TOVÁBBI KIJELZÉSEK
  Küldetésmobok: apró, tompa arany ! a név előtt, háttér és felirat nélkül; a név eredeti színével.
  A kiemelés a /mp panel alján kapcsolható. Az életerősáv aggro szerinti színe megmarad.
  Felismerés: a játék UnitIsQuestBoss jelzése és opcionálisan a Questie aktív célpontadatai,
  beleértve a küldetéstárgyat dobó mobokat. A Questie nem kötelező függőség.
  Befejezett Questie-célok jelzése eltűnik; a változásokat küldetésesemények és másodpercenkénti frissítés követi.
  Védett vagy hiányzó adatokból az addon nem találgat küldetéskapcsolatot.
  Életerő és százalék, szint / elit jelzés, kétoldali célpontkiemelés.
  Cast és channel sáv idővel, varázslatikonnal; a nem szakítható / ismeretlen állapotú sáv szürke.
  Alapból legfeljebb 8 saját debuff ikonnal és az elérhető időzítési adatokkal.
  A /mp panelen a Debuffok száma 1–12 között állítható; 6 ikon után új sorba tördel, felfelé.
  Forever kliensen a Blizzard AuraContainer / CustomAuraButton rendszere kezeli az élő ikonokat,
  a stackeket, a cooldown rajzolatát és a hátralévő időt; az addon nem olvassa ki a védett auraadatokat.
  Az aurák a saját névtáblához kapcsolódnak, a gyári UnitFrame elrejtése nem rejti el őket.
  Régebbi kliensen, ha nincs AuraContainer támogatás, a korábbi aura-lekérés marad tartalékmegoldásként.
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

ELLENŐRZÉS
  Helyi Lua/WoW-szimulációval tesztelve: a szerepkörök és aggroállapotok, három skin,
  előnézeti gombok, beállítások mentése, HP, cast/channel, saját aurák és régi aura-API,
  célpontjelzés, natív felület visszaállítása, névtábla újrafelhasználása, ismeretlen/védett adatok,
  hiányzó API-k, beállítások javítása és parancsok. A beállítópanel geometriáját külön átnéztem.
  0.1.2: a védett aurákhoz tartozó natív megjelenítő kötései, saját debuff-szűrője,
  ki-/bekapcsolása, névtábla-újrafelhasználása és leválasztása helyi szimulációval ellenőrizve.
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
