## TODO

This is a todo list of various things that would be good to have in the addon that I'd like to get done in the future.

### Hey, we can actually test in Forever now and not just semi-drycode in Midnight
- Test that the sunder debuff tracking, y'know, works
- Read spell and talent ranks from the API.
- Listen to whatever events are relevant to compute talent ranks and cache the current ones. Make a little module for it like the rest?

### Before releasing 1.0.0
- Version tag our SavedVariable DBs to support migration. Do we support migrating beta versions? Inclined to say no...
- Actually do what I say hide Sunderer when targeting a player. It's useful for debug ok...

### Future Work
1. Better overkill damage. There is an entry in the player's damage done tables that I'm pretty sure we can use.
2. Better handling of mob healing. I'm not entirely certain that removing it is desirable in practice, but we should have the option.
3. Handle damage distribution for groups that aren't 100% warriors.
- Start by just guessing a ratio of physical damage/class.
- Better solution: parse the combat log damage stats for the current ratio. Need look up table with, uh, every physical ability in the game? Good excuse to add yet another decaying average. This time we can weight it by total damage in the segment!
4. Reconsider "icon mode"? The entire addon may be better as a data source plugin for whatever weakauras is called now. Everauras?
