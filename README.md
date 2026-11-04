# Sundered

Sundered is an addon for World of Warcraft Forever. It estimates the damage done by Sunder Armor on your current target to help you compare Sunder Armor with other abilities.

Because of the secret value restrictions in modern World of Warcraft, Sundered is only able to provide an estimate of the value of various abilities, including Sunder Armor. If you have temporary buffs then they will _not_ be accounted for. It's the best and most useful estimate I can manage, but it is an estimate.

Sundered is currently very inaccurate in parties, and worse in raids. The accuracy for group play will be improved in the future, but having other players hit your mob generally makes estimating the value of a Sunder more difficult.

To install Sundered, unzip a relevant release to World of Warcraft/\_forever\_/Interface/AddOns. Use `/sundered` to open the options, or use the regular Addon options tab.

## Features

- Displays Sunder Armor's estimated damage value as a status bar.
- Tracks Sunder Armor's stacks and remaining duration on your current target.
- Compares your expected Sunder Armor damage with the expected damage of other abilities to help with rotational decisions.

## Generative AI Use

LLM-based coding tools were used to develop this addon. One of my personal goals with the project was to tinker with running various coding agents locally on my GPU and see how that works nowadays. Turns out the answer is "kinda poorly", especially when you have to launch a video game to debug, so various cloud agents were used in the more recent commits.

I wouldn't call it vibe coded, but of course I am biased. I've been a software engineer for 15 years and I read every line ol' Slopsy produced, even the very boring UI code that, really, no one should read. That said, if you prefer to not use code that was produced by an LLM then please don't install this addon.

## FAQ

### How do you compare Sunder Armor to a direct damage attack, anyhow?

We use effective hit points.

To explain by way of example: say a mob has 1000 HP and a 50% damage reduction from armor. We say the mob has an 2000 EHP. Damaging abilities "hit" EHP directly: if your Mortal Strike's listed damage is 500 then hitting the mob reduces its HP by 250, but its EHP by 500.

Sunder also does damage to EHP. Say 1 application of Sunder Armor reduces our mob from 50% reduction to 33%. That reduces the EHP of the mob from 2000 to 1500. Your Sunder Armor is _also_ effectively an attack with 500 listed damage.

Obviously the numbers are different in the game, but hopefully the idea is clear.

### Aren't secret values supposed to stop this sort of automated decision thing?

They are! Sundered needs to know the exact health of a mob to know its effective health, and that's secret. You might think Sundered also needs to know the mob's armor value but for math reasons it turns out you only need the level of the attacker, which isn't secret.

Sundered gets around the limitation of secret health in a simple 5-step process:
1. We can't access `UnitHealth` but we are allowed to scale percent health by a factor for display. We actually only need `UnitHealthMax`.
2. `UnitHealthMax` is equally as secret, but has the advantage of being fixed for a given creature ID and level. We just need a database of these values. Unfortunately, we don't have such a database yet.
3. Fortunately, we can build the DB on the fly. Sundered looks at the total damage done to a mob in the Blizzard damage meter after you kill it and uses that as a health estimate.
4. We use this estimate to update two decaying averages: one for a mob of that level, and one for a mob of that level and creatureID.
5. On targeting in combat we look up the current target in the cache based on level and creatureID if possible. If creatureID isn't cached, fall back to the coarser level-only estimate. If level isn't cached, fall back to a hardcoded approximate HP table.

This is not exact. Overkill damage and mob self healing will cause errors. Sundered's estimates are estimates. It's also very new and untested in Forever so I'm sure there are many fun ways it can bug out.

### Why doesn't the estimated damage value change with the Sunder Armor stack count?

That's how the armor math works out. It doesn't matter if a mob has 500 or 5000 armor: a Sunder Armor stack does the same EHP damage.

### What about the other abilities? How does Sundered know what damage they will do?

Sundered doesn't know _exactly_ what damage they will do. The amounts shown are again estimates, in this case computed based on your typical stats after a fight. If you get a +damage proc (for example: Enrage) then the will be more effective than indicated for the duration. There's no way for Sundered to account for any temporary buffs or debuffs that you get mid fight.

### What about PvP? Is this what I need to cruise effortlessly to High Warlord?

Sundered shows nothing when targeting a player. I'm not interested in handling the pvp use case.

### Are there any other limitations?

Sundered can't account for mob armor getting debuffed to 0, which I believe is the lowest that armor can go from debuffs in Forever. You aren't going to hit that limit in most fights, but there are a few exceptions:
- Fighting (much) lower level mobs.
- Fighting caster mobs with the "Mage" mob armor scaling type.
- You have a Hunter and Druid in your party and they're keen on armor redutcion.

In these cases Sundered will be wrong for the 5th and possibly 4th stack, if vanilla mechanics apply. It may be possible for me to account for this in the future.

### Is Blizzard going to ban this sick filth?

There's no illegal hacking going on. This is built entirely on the public WoW API. I could instead just make a giant database of mob health levels by ID, and I might in a week. It's unlikely that Blizzard cares that deeply about the sanctity of warriors' Sunder decision making when fighting open world mobs in any case.

## License
This addon is Copyright (c) 2026 Karl Schmidt.
This addon is released under the [Mozilla Public License 2.0 (MPL-2.0)](https://www.mozilla.org/en-US/MPL/2.0/).