extends GutTest
## Crew-voice resolver (ADR 0014). α0.1 has no crew, so every post answers in the
## ship's-computer voice. This is the seam the crew system later plugs into.


func test_unmanned_post_uses_ship_voice() -> void:
	assert_eq(CrewVoice.speaker_for("helm"), CrewVoice.SHIP_VOICE, "Helm is unmanned -> ship voice")
	assert_eq(CrewVoice.speaker_for("ops"), CrewVoice.SHIP_VOICE, "any post -> ship voice in α0.1")


func test_ship_voice_is_a_translation_key() -> void:
	assert_eq(CrewVoice.SHIP_VOICE, "VOICE_SPEAKER_SHIP", "speaker name resolves via tr()")
