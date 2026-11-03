# Sundered

Sundered is an addon for World of Warcraft Forever. It estimates the damage done by Sunder Armor on your current target to better help you compare Sunder Armor with other, more straight-forward abilities. It is primarily intended for leveling and open world solo gameplay.

Note that, because of the secret value restrictions in modern World of Warcraft, Sundered is only able to provide an estimate of the value of various abilities, including Sunder Armor. If you have a big temporary buff or similar then it will _not_ be accounted for. Accuracy is bad in dungeons, and worse in raids. I hope to improve the accuracy in dungeons somewhat in the future, but it's never going to be great and it's not my focus.

To install Sundered, unzip a relevant release to World of Warcraft/_forever_/Interface/AddOns. Use `/sundered` to open the options, or use the regular Addon options tab.

## Features

- Displays Sunder Armor's estimated damage value in a status bar.
- Optionally tracks Sunder Armor's stacks and remaining duration on the current target.
- Lets you directly compare your expected Sunder Armor damage with the expected damage of other abilities to help with rotational decisions.

## Generative AI Use

"AI" tools were used to develop this addon. One of my personal goals with the project was to tinker with running various coding agents locally on my GPU and see how that works nowadays. Turns out the answer is "kinda poorly", so various cloud agents did a lot of the newer work.

I wouldn't call it vibe coded, but of course I am biased. I've been a software engineer for 15 years and I read every line ol' Slopsy produced, even the very boring UI code that, really, no one should read. That said, if you prefer to not use code that was produced by an LLM then please don't install this addon.

## FAQ

### How do you compare Sunder Armor to a direct damage attack, anyhow?

We can use effective hit points to compare them.

To explain by way of example: say a mob has 1000 HP and a 50% damage reduction from armor. You need to do 2000 "raw" damage to kill the mob, so we say the mob has an 2000 effective hit points. Damaging abilities "hit" EHP directly: if your Mortal Strike's listed damage is 500 then hitting the mob reduces its health by 250, but its EHP by 500.

Sunder also does damage to effective health. Say 1 application of Sunder Armor reduces our mob from 50% reduction to 33%. That reduces the raw damage needed to kill the mob from 2000 HP to 1500 HP. Your Sunder Armor is effectively an attack with 500 listed damage.

Obviously the numbers are different in the game, but hopefully the idea is clear.

### Aren't secret values supposed to stop this sort of automated decision thing?

They are! Specifically Sundered needs to know the exact health of a mob to know its effective health, and that's secret. You might think Sundered also needs to know the mob's armor value but for math reasons it turns out you only need the level of the attacker, which isn't secret.

Sundered gets around the limitation of knowing health in a couple of ways:
- While we can't get current health, we are allowed to scale percent health by a factor. This means we only actually need max health.
- Max health is still secret, but we can estimate it. Sundered will look at the total damage done to a mob in the Blizzard damage meter after you kill it, and assume that's roughly the health of the mob.
- We're still not able to look up mobs by a specific identifier like its name or creature ID while in combat, so instead Sundered looks them up by indirect identifiers like level, classification (normal, elite, etc), and current zone that we can check in combat.

This is not exact. Sundered's estimates are estimates. The mob health estimates get better as you do more murders, but they will never be exact. It's also very new and untested in Forever so I'm sure there's a lot of fun ways it can bug out.

### Why doesn't the estimated damage value change with the Sunder Armor stack count?

That's just how the armor math works out. It doesn't actually matter if a mob has 500 or 5000 armor: applying a Sunder Armor stack does the same EHP damage either way.

### What about the other abilities? How does Sundered know what damage they will do?

Sundered doesn't know what exactly damage they will do. The amounts shown for other abilities are likewise estimates, in this case computed based on your typical stats after a fight. If you get an important +damage proc (for example: Enrage) or other buff then the will be significantly more effective than indicated. There's no way for Sundered to account for any temporary buffs or debuffs that you get mid fight. All it can do is try to estimate what the average result is.

### What about PvP? Is this what I need to cruise effortlessly to High Warlord?

Sundered shows nothing when targeting a player and likely never will. There's no way to get any sort of current health estimate for players that I know of, and if there is one I don't know of then I have no interest in implementing it.

### Are there any other limitations?

Sundered can't account for mob armor hitting 0, which I believe is the lowest that armor can go from debuffs in Forever. You aren't going to hit that limit in most fights, but there are a few exceptions:
- Fighting lower level mobs.
- Fighting caster mobs with the "Mage" mob armor scaling type when you have a recent Sunder rank.
- You have a Hunter and Druid in your party and they're keen on armor redutcion.

In these cases Sundered will be wrong for the 5th and maybe 4th stack if vanilla mechanics apply. It may be possible for me to account for this in the future, but I'm frankly not sure it's worth the effort.

### Is Blizzard going to ban this sick filth?

There's no illegal hacking going on, this is just normal, public WoW API stuff. I could instead just make a giant database of mob health levels by ID, and I might in a week. It's unlikely that Blizzard cares that deeply about the sanctity of warriors' Sunder decision making when fighting open world mobs in any case.

## License
This addon is Copyright (c) 2026 Karl Schmidt.
This addon is released under the [Mozilla Public License 2.0 (MPL-2.0)](https://www.mozilla.org/en-US/MPL/2.0/).