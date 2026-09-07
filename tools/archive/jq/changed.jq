# Is the manifest meaningfully different from what's currently published?
# `.generated` is ignored - the manifest no longer carries one, but a
# previously published manifest may.

($existing[0] // {} | del(.generated)) != ($manifest[0] // {} | del(.generated))
