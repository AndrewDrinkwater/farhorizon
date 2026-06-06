class_name CrewVoice
extends RefCounted
## Resolves who answers an order at a console post (ADR 0014). The acknowledgment
## voice is the crew officer manning the post, or the ship's computer if the post
## is unmanned. In α0.1 there is no crew, so every post answers in the ship voice.
##
## This is the single seam the crew system later plugs into: assign officers to
## posts and named voices light up everywhere with no console changes. Pure +
## node-free so it's GUT-testable.

## tr() key for the ship's-computer speaker name (the α0.1 fallback voice).
const SHIP_VOICE: String = "VOICE_SPEAKER_SHIP"


## Returns the speaker name (a tr() key) for `post` — an officer's name once crew
## exists, the ship voice while the post is unmanned.
static func speaker_for(_post: String) -> String:
	# α0.1: no crew assignments yet; the ship's computer answers every post.
	return SHIP_VOICE
