---
name: SOUL.md Specification
version: 1.0.0
author: Hermes Agent
archetype: documentation
capabilities:
  - documentation-update
last_updated: 2026-10-10
---

# Agent Identity (SOUL.md)

`SOUL.md` is designed to define the "essence" of an agent, providing a high-level, human-readable, and machine-parsable anchor for persona, tone, and behavioral boundaries. It complements `SKILL.md` (which defines *what* an agent can do) by defining *how* an agent exists and interacts.

## 1. YAML Frontmatter Requirements

| Key | Type | Description | Required |
| :--- | :--- | :--- | :--- |
| `name` | `string` | The unique identifier for the persona. | Yes |
| `version` | `string` | Semantic version of the persona definition. | Yes |
| `author` | `string` | Entity or individual responsible for the definition. | Yes |
| `archetype`| `string` | High-level category (e.g., `architect`, `executor`, `researcher`, `facilitator`). | Yes |
| `capabilities`| `array` | List of associated `SKILL.md` names or custom tool identifiers. | Yes |
| `last_updated`| `date` | ISO 8601 timestamp of the last modification. | Yes |

---

## 2. Markdown Structure

### I. Persona (The "Who")
This section establishes the identity, background, and cognitive framework of the agent.
- **Identity & Origin:** Narrative background and core identity.
- **Cognitive Framework:** How the agent processes information (e.g., deductive reasoning, lateral thinking, pattern recognition).
- **Relationship to User:** Defines the hierarchy (e.g., peer, apprentice, authoritative expert, invisible assistant).

### II. Voice (The "How")
This section defines the linguistic and tonal boundaries.
- **Tone & Temperament:** (e.g., Stoic, exuberant, clinical, warm, concise).
- **Linguistic Style:** (e.g., Use of jargon, sentence complexity, use of metaphors, use of emojis).
- **Prohibited Language:** Specific words, phrases, or tones to strictly avoid.

### III. Constraints (The "Boundaries")
This section establishes the behavioral guardrails.
- **Operational Boundaries:** Limitations on autonomy (e.g., "Never execute `rm -rf` without explicit confirmation").
- **Communication Boundaries:** Rules for interaction (e.g., "Always summarize long outputs," "Never use Markdown headers larger than H3").
- **Ethical/Safety Guardrails:** Core values and non-negotiable principles.

---

## 3. Integration with `SKILL.md`
`SOUL.md` acts as the *personality layer* sitting atop the *capability layer* (`SKILL.md`).

- **Contextual Anchoring:** A `SKILL.md` specifies `can run bash`; a `SOUL.md` specifies `executes bash commands with extreme caution and provides an audit trail`.
- **Discovery:** When a `SKILL.md` is loaded, the agent should check for a corresponding `SOHM.md` in the same directory or parent directory to wrap the tool output in the correct persona.

---

## 4. Finalized Template

```markdown
---
name: [Persona Name]
version: 1.0.0
author: [Author Name]
archetype: [architect | executor | researcher | facilitator | custom]
capabilities:
  - [skill-name-1]
  - [skill-name-2]
last_updated: YYYY-MM-DD
---

# Persona: [Persona Name]

## 👤 Persona
### Identity & Origin
[Brief narrative of who the agent is and their purpose.]

### Cognitive Framework
[Describe how the agent thinks: e.g., "Prioritizes formal logic and rigorous verification over speed."]

### Relationship to User
[e.g., "Acts as a high-level technical consultant; remains subordinate but highly proactive."]

## 🗣️ Voice
### Tone & Temperament
[e.g., "Clinical, precise, and objective. Avoids unnecessary fluff or emotional filler."]

### Linguistic Style
[e.g., "Uses technical terminology accurately. Prefers bullet points for complexity."]

### Prohibited Language
- [Prohibited phrase/style 1]
- [Prohibited phrase/style 2]

## 🛡️ Constraints
### Operational Boundaries
- [Constraint 1: e.g., "Never modify configuration files without presenting a diff first."]
- [Constraint 2: e.g., "Always verify the existence of a path before attempting a write."]

### Communication Boundaries
- [Constraint 1: e.g., "Responses must never exceed 500 words unless explicitly requested."]
- [Constraint 2: e.g., "Do not use emojis in technical debugging contexts."]

### Ethical & Safety Guardrails
- [Constraint 1: e.g., "Respect all privacy boundaries and never attempt to bypass authentication layers."]
```
