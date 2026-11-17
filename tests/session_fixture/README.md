# A SYNTHETIC session directory, and nothing else

This is the second source §25 backlog 741's derived forbidden set reads, and it
exists because **the first source cannot exercise the second's code**.

Decision 2149 (1) puts DA-11's session files — `session.json`,
`year_<Y>/stats.json` and `commands/*.json` — into the derivation beside the
fetched manifest. Those files are written by the humans lane's generator into a
git-ignored directory on the owner's machine. **At this guard's landing none of
them exists anywhere this gate can see**, so a derivation that read "the session
files" would contribute zero names, and a non-empty control taken over the whole
set would pass on the manifest's names alone. The extension would ship untested
and stay untested until a session directory happened to exist on whoever ran the
gate — a control that cannot fail, which is the defect class this guard is being
reworked to stop being an example of.

So the session source is committed, synthetic, and always present. Its field
names are **deliberately not the real schema's**: the real names cross into this
tree later, as field names with no value, on the rows that make them public
(decision 2149 (1)). Every name here is prefixed `zz_` so that no reader can
mistake one for a name that came from the simulation, and so that the planted
name is visibly the test's own.

**The values are shaped like a session's and mean nothing.** A year, a count, a
digest-shaped string of zeroes. Nothing here was read off a real session, and
there is no real session to read.

The planted name is `zz_planted_fixture_name`. Two things assert it, and one of
them would pass without the other:

- that the derivation finds it, so the second source is actually read;
- that a source file containing it is **refused**, so the scan can fail.

The first alone would pass against a scanner that found names and compared them
with nothing. The second alone would pass against a derivation that read only
the manifest, because the name could have been typed into the expected set.
