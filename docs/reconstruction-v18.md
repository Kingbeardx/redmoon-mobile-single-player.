# v0.18 reconstructed game systems

This release supplies playable replacements for the six previously unavailable
player entries, twelve monster entries, later campaign, combat pipeline and
multiplayer. It is a reconstruction from surviving resources, not a claim of
bit-identical JCE behavior or a complete public MMORPG service.

## Play

Install the Android APK over the previous version to keep local progress.
New characters start with full RPG combat.
The modified MOP pack placed one-hit event enemies beside the starting point.
Before level 50 the full-rules Backyard therefore uses a reconstructed training
population, progressing through original records 7/1/2/3. It is bounded to three
creatures, scales health/damage for solo play, and respawns every eight seconds.
Other maps retain their source populations; the Backyard returns to its source
population after level 50. Existing saves retain their previous
balance; BAG → JOURNEY → PARTY → COMBAT switches between full and simple rules.
Switching preserves health fractions, defeated enemies and saved ground loot.

Use BAG → JOURNEY → PARTY to recruit up to two allies, select a support target,
choose a Gate destination, or use an active Gate. Allies follow and fight, retain
health across saves, and can fall in battle. Their maximum health scales with
the owner's base Power; dead allies remain dead when the maximum changes. Recall moves an ally to the caster;
Teleport moves the caster to an ally; Resurrection revives a nearby fallen ally
using half the caster's current HP and the original full-MP requirement. Gate
creates a 60-second route and takes recruited allies with the traveler.

Concentration adds 15 to the hit calculation; Rabbit's Foot multiplies attack
success by 1.2. Both affect the full combat model. All original class, level,
honor, weapon and MP/DP requirements remain enforced. All 114 player records and
36 monster records have an executable gameplay implementation.

Finish the recovered Spy/Esper chapter, then open JOURNEY → CAMPAIGN CONTINUATION.
Seven authored missions continue through Sahara 2, the Himalayan caverns, the
spaceship and four Signus areas, with reports to Kasham and an ending. Later
honor caps reach 500 and 1000. Early leads come from Message.ctf 0:7:255..275;
mission objectives, encounters, scaling, rewards and ending are new authored
content. These do not reproduce the 43 deleted event-program slots.

Full-rules Esper uses a rebuilt solo instance, retaining the source boss and
coordinates. The normal MMO population returns outside that mission. The later
campaign also uses private mission encounters on original maps; ambient server
populations return when those missions end. Encounter health scales with attack
power and divides the encounter budget among the required targets. Summons in
these missions use smaller scaled health/damage. Original ordinary-world health
remains based on the source Constitution formula.

## Combat and monsters

Full combat includes hit/miss, variable attack damage, Strength and Spirit growth,
weapon attacks, psychic attacks, armor/Power mitigation, source monster health,
attack ranges/intervals, control effects, MP/SP/DP, recovery, shields, reflection,
leech/drain, healing, deaths and respawns. Native components include the piecewise
Strength attack, health/MP products, minimum-attack and base accuracy curves,
class growth and XP. Integration includes explicit replacement rules:

- Player hit chance has a 65% floor; enemy chance has an 85% ceiling.
- Power mitigation is capped at 50%; armor subtracts from physical damage.
- Psychic attack growth uses the recovered attack curve with Spirit as input;
  this is a reconstruction, not an independently verified native psychic formula.
- Full-rules healing charges restore at least 30% of maximum HP. Quick food picks
  the largest useful recovery from available food/drink. Source food values still
  determine item recovery; some legacy special/encoded effects remain unverified.

Monster additions perform recoverable item theft, dropped-item attacks,
concealment, sleep/damage/dispel, curse, reinforcements, linked healing, linked
cleansing and group blessing. Theft excludes equipped gear and quest items;
recover stolen items by defeating the thief. Summons are real combatants, limited
to three per parent life and six extra entities per map. Linked healers have
three healing charges per life to avoid indefinitely replenishing authored bosses.
The reconstructed guards use existing monster IDs 52/55 and original artwork.

The full model delivers the listed source drop stacks rather than just the first
entry. Native DropMoney at 0x433598..0x4335a8 uses item kind 5/index 0; DropSigMoney
at 0x433668..0x433678 uses kind 5/index 2. These go into Gold and Signus-credit
wallets. A BankClerk offers a reconstructed 1:1 exchange. Historical random-drop
selection probabilities are not asserted to be recovered. The source-described
Poison Pill (6:67) resets allocated attributes, refunds points using class growth,
and removes gear whose requirements are no longer met.

## Real multiplayer

JOURNEY → LAN CO-OP hosts or joins a four-player ENet session on UDP 24838.
Use the same LAN, or a host address reachable through an explicitly configured
network. The address screen supports native text entry and an on-screen keypad.
No matchmaking, public account database, original-server protocol compatibility,
guild services or PvP is claimed. No public server was deployed.

The host validates movement and actions, simulates enemies, awards loot/XP and
leads area travel/campaign progress. Guests import local characters for trusted
co-op, so this is not an anti-cheat/ranked economy. Combat, food, gear, shops,
banking, stats, hotbar binding, companions and support requests run on the host.
Snapshots include guest progress, effects, resources and party state.
Nearby living players share source kill XP, with each character's ordinary XP cap;
this cooperative sharing rule is newly authored. Host AI can
target guests; guest kills advance the shared campaign. A host can resurrect a
fallen connected guest. DISCONNECT & KEEP PROGRESS saves the guest locally.

Networking uses a new protocol and does not require executing legacy servers.
Android INTERNET permission is enabled for ENet; ordinary solo play remains offline.
Co-op uses a shared area and host-led travel. Snapshot transport is reliable;
client-to-client relaying is disabled because all actions go through the host.

## Validation and historical limits

The advanced full-rules play scenario uses a legal level-400 Sadad point budget
and a supplied stack of original recovery items, with ordinary attacks, skills,
movement, enemy AI, food and party actions. It clears Spy, Esper and all seven
continuation missions without direct damage injection or invulnerability. This
is a test fixture, not proof of every class/build/difficulty combination.

Actual separate Godot processes test host/guest movement, authoritative attacks,
invalid stat rejection, companion recruitment, AI guest targeting and resurrection.
Four processes verify three simultaneous guests and clean disconnections.
The UI test clicks recruitment, Resurrection and campaign start and checks co-op
controls/keypad. Existing story, save, UI, music and touch suites remain included.
Physical Android/Wi-Fi performance and iOS compilation are not verified here.

The historical 43 Removed slots, 56 client-only map candidates and 18 missing or
mismatched RMD references remain archival gaps. Other legacy special items may be
reference-only. See recovery-status.md for exact paths and caveats. These limits
prevent a claim that every original publisher-era behavior or asset is restored.
