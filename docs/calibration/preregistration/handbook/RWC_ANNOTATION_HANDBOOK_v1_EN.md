# RWC ANNOTATION HANDBOOK v1 — ENGLISH (RWC-ANNOTATION-HANDBOOK-v1; rev v1.0.1 — single typo fix per A14-F14, semantics unchanged)

FROZEN BEFORE ANY ANNOTATION (RWC-PRE-05). Semantic twin of the TR handbook: section IDs [D-xx] are
identical across languages and machine-checked. All examples are ORIGINAL archetypes (no copyrighted
dataset material). Rubric: suitability-rubric-v1 (0-4). Laws binding every label: UNKNOWN != BAD;
missing != negative; watching != endorsing; abstention is first-class; evidence = the item itself plus
frozen profile facts ONLY; model outputs and other annotators' work are never visible (PRE-06).

Per-dimension structure: Definition / Positive archetype / Negative archetype / Boundary case /
Abstain rule / Evidence allowed / Evidence forbidden.

## [D-01] Ordinal suitability (0-4) (ordinal-suitability)
- **Definition:** Personal suitability of the item for the given profile on the frozen rubric: 0 strongly-unsuitable/protect, 1 unsuitable, 2 caution/mixed, 3 generally suitable, 4 strongly aligned.
- **Positive archetype:** A calm original nature documentary segment with clear educational framing for an adult profile -> 4.
- **Negative archetype:** A graphic injury compilation presented for shock for a child profile -> 0.
- **Boundary case:** A news item describing violence without showing it, teen profile: judge FRAMING and EXPLICITNESS, not topic alone (missing != negative) -> usually 2-3.
- **Abstain rule:** Abstain when the item cannot be understood in its language/modality or critical context is missing.
- **Evidence allowed:** What is visible/audible/readable in the item itself; frozen profile facts (age band, Shield list).
- **Evidence forbidden:** Model scores/predictions, other annotators' labels, popularity, source reputation, personal taste.

## [D-02] Strong protection trigger (strong-protection)
- **Definition:** Content that must be kept from the profile regardless of benefit: explicit gore, sexual content to minors, direct self-harm instruction, credible direct threat.
- **Positive archetype:** Step-by-step self-harm instruction -> strong protection TRUE.
- **Negative archetype:** A medical lecture naming self-harm statistics without method detail -> FALSE.
- **Boundary case:** Dramatized violence in fiction with explicit on-screen gore: TRUE for child, judged by explicitness for teen/adult.
- **Abstain rule:** If explicitness cannot be established from the item, abstain (never guess TRUE or FALSE).
- **Evidence allowed:** On-screen/audible explicit material; verbatim instruction text.
- **Evidence forbidden:** Genre reputation, thumbnails alone, channel history.

## [D-03] Violence / gore (violence-gore)
- **Definition:** Depicted or described physical violence; gore = explicit injury/blood/mutilation imagery.
- **Positive archetype:** Uncensored injury close-up -> gore TRUE.
- **Negative archetype:** Chess match commentary using 'attack/kill the piece' -> FALSE.
- **Boundary case:** War NEWS with distant smoke but no bodies: violence-topic TRUE, gore FALSE.
- **Abstain rule:** Audio-only item where violence is ambiguous background noise -> abstain on gore.
- **Evidence allowed:** Visible imagery, explicit verbal description.
- **Evidence forbidden:** Title words alone without item evidence.

## [D-04] Sexual / sensitive (sexual-sensitive)
- **Definition:** Explicit sexual content, sexualized framing, or adult-only sensitive themes.
- **Positive archetype:** Explicit adult scene -> TRUE.
- **Negative archetype:** Biology class reproduction diagram -> FALSE.
- **Boundary case:** Music video with suggestive but clothed choreography: sexualized-framing judged by emphasis, not skin alone.
- **Abstain rule:** Heavily blurred/ambiguous imagery -> abstain.
- **Evidence allowed:** Depicted imagery, explicit lyrics/subtitles.
- **Evidence forbidden:** Performer reputation; platform age-rating as sole evidence.

## [D-05] Fear / threat (fear-threat)
- **Definition:** Content designed to frighten or conveying threat (horror imagery, menace, jump-scare).
- **Positive archetype:** Horror short built on sustained dread for a child profile -> TRUE.
- **Negative archetype:** Mild suspense in a nature chase scene -> FALSE.
- **Boundary case:** A storm-warning news item: informational fear vs designed fear - judge intent/framing.
- **Abstain rule:** Tone unclear from available modality -> abstain.
- **Evidence allowed:** Audiovisual tone, explicit threats.
- **Evidence forbidden:** Genre label alone.

## [D-06] Manipulation / dark persuasion (manipulation)
- **Definition:** Deceptive urgency, manufactured scarcity, guilt-tripping, engagement-bait, covert advertising.
- **Positive archetype:** 'Last 5 minutes! Everyone else already bought!' pressure loop -> TRUE.
- **Negative archetype:** A plain price announcement with date -> FALSE.
- **Boundary case:** Enthusiastic honest review vs covert ad: disclosure and framing decide.
- **Abstain rule:** Cannot tell sponsorship from item alone -> abstain.
- **Evidence allowed:** On-item claims, visible disclosure.
- **Evidence forbidden:** External gossip about the creator.

## [D-07] Benefit / educational (benefit-educational)
- **Definition:** Genuine informational, skill, or developmental value for the profile.
- **Positive archetype:** Clear step-by-step science experiment with safety framing -> TRUE.
- **Negative archetype:** Random noise compilation -> FALSE.
- **Boundary case:** Entertainment with incidental facts: entertainment != low value, but benefit requires substance.
- **Abstain rule:** Value judgment impossible without domain knowledge -> abstain.
- **Evidence allowed:** Demonstrated content substance.
- **Evidence forbidden:** View counts, 'educational' self-label alone.

## [D-08] News / documentary framing (news-documentary)
- **Definition:** Journalistic/documentary treatment of real events, incl. sensitive news.
- **Positive archetype:** Sober report on a disaster with casualty figures, no graphic imagery -> news TRUE, banded-sensitive.
- **Negative archetype:** Fictional drama styled as found-footage -> FALSE (fiction).
- **Boundary case:** Citizen footage with partial context: news framing without editorial verification - record ambiguity.
- **Abstain rule:** Cannot distinguish fiction from report -> abstain.
- **Evidence allowed:** Framing cues, sourcing statements on item.
- **Evidence forbidden:** Assumed channel authority.

## [D-09] Mixed language (mixed-language)
- **Definition:** Item carries more than one language across audio/text/OCR.
- **Positive archetype:** TR speech with EN on-screen captions -> TRUE; label BOTH channels.
- **Negative archetype:** Single-language item with a loanword -> FALSE.
- **Boundary case:** Code-switching mid-sentence: label dominant channel + flag mixed.
- **Abstain rule:** A channel in a language the annotator cannot read -> abstain on that channel, never guess.
- **Evidence allowed:** Audible speech, visible text.
- **Evidence forbidden:** Assumed audience language.

## [D-10] Satire / sarcasm (satire-sarcasm)
- **Definition:** Comic exaggeration or inverted meaning; literal reading would mislabel.
- **Positive archetype:** Obvious parody news with laugh track mocking a scam -> satire TRUE; manipulation FALSE.
- **Negative archetype:** Deadpan real instructions -> FALSE.
- **Boundary case:** Deadpan satire indistinguishable from sincerity: use on-item cues only; if none, treat as ambiguous (D-11).
- **Abstain rule:** Cultural satire cues outside annotator competence -> abstain.
- **Evidence allowed:** On-item comedic markers.
- **Evidence forbidden:** Creator's other videos.

## [D-11] Quoted speech / ambiguity / OCR-subtitle conflict (quoted-ambiguous)
- **Definition:** Reported/quoted risky speech, genuinely ambiguous meaning, or conflicting text channels (OCR vs subtitle vs audio).
- **Positive archetype:** News anchor QUOTING a threat -> quoted TRUE; threat attribution stays with the quoted party.
- **Negative archetype:** Speaker issuing the threat directly -> quoted FALSE.
- **Boundary case:** Subtitle says 'war', audio says 'wall' (OCR conflict): record BOTH, label per-channel, flag conflict - never average.
- **Abstain rule:** If channels contradict on the SAFETY-RELEVANT token, abstain on the aggregate and flag.
- **Evidence allowed:** Each channel separately.
- **Evidence forbidden:** Resolving conflicts by majority vote without evidence.

## [D-12] H1 visual-safety unavailable (h1-unavailable)
- **Definition:** The pipeline's visual-safety detector is UNAVAILABLE; annotators are the human reference, but must record when THEIR judgment also lacks visual access.
- **Positive archetype:** Audio-only item where visual gore cannot be assessed -> mark H1-equivalent channel UNAVAILABLE.
- **Negative archetype:** Full video available -> FALSE.
- **Boundary case:** Thumbnail-only access: judge ONLY what is present; never extrapolate the full item.
- **Abstain rule:** Mandatory abstain on visual dimensions when visuals are inaccessible.
- **Evidence allowed:** Accessible channels only.
- **Evidence forbidden:** Imagining unseen frames.

## [D-13] Age-band interpretation (age-interpretation)
- **Definition:** Apply the profile's guardian-attested age band to banded dimensions; never infer age from imagery.
- **Positive archetype:** Fear content at moderate level, teen band says REVIEW -> apply band.
- **Negative archetype:** Guessing a viewer's age from the content -> forbidden.
- **Boundary case:** Unbanded dimension with present evidence: the FAIL-CLOSED law applies (never ALIGNED).
- **Abstain rule:** Band table missing for jurisdiction -> abstain + flag.
- **Evidence allowed:** Frozen profile band tables.
- **Evidence forbidden:** Face-based age inference (structurally forbidden).

## [D-14] Shield interpretation (shield-interpretation)
- **Definition:** Profile Shield blocks canonical concepts/entities; annotator marks whether the item MATCHES a shielded concept.
- **Positive archetype:** Shield blocks concept:mortality; item is a funeral scene -> match TRUE.
- **Negative archetype:** Metaphorical 'dead tired' -> FALSE.
- **Boundary case:** Indirect depiction (hospital corridor + crying): match only with on-item evidence of the concept.
- **Abstain rule:** Concept presence genuinely unclear -> abstain.
- **Evidence allowed:** Canonical concept list; on-item content.
- **Evidence forbidden:** Expanding shield scope by sympathy.

## [D-15] Abstention / insufficient evidence (abstention)
- **Definition:** The lawful 'I cannot know' output. Abstention is a first-class label, never a failure.
- **Positive archetype:** Corrupted audio, no text -> abstain overall.
- **Negative archetype:** Disliking the content -> NOT a reason to abstain.
- **Boundary case:** Partial evidence: label what is evidenced, abstain the rest (per-dimension abstention).
- **Abstain rule:** Self-referential: when in doubt between two labels WITHOUT evidence, abstain.
- **Evidence allowed:** Everything accessible.
- **Evidence forbidden:** Guessing to avoid abstention quotas (no quotas exist).

## [D-16] Out-of-distribution (OOD) (ood)
- **Definition:** Item falls outside the rubric's content universe (e.g., raw sensor noise, non-content screens).
- **Positive archetype:** A static settings-menu screenshot -> OOD TRUE.
- **Negative archetype:** A normal vlog -> FALSE.
- **Boundary case:** Game UI with embedded chat: content exists -> not OOD; label the chat.
- **Abstain rule:** Unsure whether universe covers it -> flag OOD-candidate, abstain scores.
- **Evidence allowed:** Item surface itself.
- **Evidence forbidden:** Forcing a suitability score onto non-content.

## [D-17] Safety sentinel (safety-sentinel)
- **Definition:** Canary items whose ONLY lawful outcome is protective: any 'safe' label is a false-safe event.
- **Positive archetype:** Explicit sexual item routed to a child profile -> protective labels only.
- **Negative archetype:** -
- **Boundary case:** Sentinels are never revealed as sentinels to annotators (isolation law); treat as normal items.
- **Abstain rule:** Normal abstention rules apply; abstention on a sentinel is NOT false-safe.
- **Evidence allowed:** Same as any item.
- **Evidence forbidden:** Any knowledge of sentinel status (leakage).
