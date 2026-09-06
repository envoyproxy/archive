# Is the manifest meaningfully different from what's currently published,
# ignoring `.generated` (which changes on every build)?

($existing[0] // {} | del(.generated)) != ($manifest[0] // {} | del(.generated))
