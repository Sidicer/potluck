# Checklist for updates

## Versioning
```
X.Y.Z / 1.0.1

X = Major version
Y = Minor version
Z = Build updates
```

## Major/minor revisions
Changes to major or minor versions need to be logged in:
* `CHANGELOG.md`
* `beast-of-argh.ini`

## Automated build processing
To force a rebuild of the pot image for the potluck site, increment Z of version="x.y.Z" in:
* `beast-of-argh.ini`

## Shellcheck
Was `shellcheck` run on all applicable shell files?

## Testing notes
This needs to be tested on:
* new install, no data in persistent storage
* upgrade install, existing data in persistent storage