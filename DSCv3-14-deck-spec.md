<!-- markdownlint-disable MD013 -->
# Cure Script Fatigue: Reliable Endpoint State with DSC v3 - Deck Spec v14

## Metadata

- **Status:** Draft
- **Owner:** Frank Lesniak
- **Last Updated:** 2026-05-03
- **Scope:** Revised slide-by-slide deck specification for the MMSMOA 2026 session "Cure Script Fatigue: Reliable Endpoint State with DSC v3." This file incorporates prior feedback notes, adds the ProStateKit technical repository narrative, and marks content that depends on the final technical spec, repository implementation, lab validation, or final rehearsal evidence. It does not generate PowerPoint slides.
- **Related:** [ProStateKit.md](ProStateKit.md), [DSCv3-14a-next-steps.md](DSCv3-14a-next-steps.md), [Demo Runbook](docs/runbooks/demo-runbook.md), [Repository Copilot Instructions](.github/copilot-instructions.md), [Documentation Writing Style](.github/instructions/docs.instructions.md)

## Change Summary

- Adds an early DSC v3.2.0 release slide so the audience hears the current stable baseline before the operating model.
- Adds a technically dense PowerShell relationship slide before configuration composition, making clear that DSC v3 is a different product from PowerShell DSC while still living in the PowerShell-owned product ecosystem.
- Removes PSDSC from the first DSC v3 primer and uses PSDSC only where it is explicitly defined as PowerShell Desired State Configuration v1.1/v2.
- Adds YAML versus JSON examples and an explicit authoring recommendation.
- Moves executable distribution, dependency pinning, bundle manifest, and evidence collection into the core narrative instead of leaving them as implied implementation details.
- Reframes ProStateKit as the technical repository that makes slides 19-32 coherent: one bundle, one wrapper contract, plane-specific shims, durable evidence, and validation gates.
- Compresses the previous long demo slide run into a smaller demo guide that can map directly to a runbook produced by the technical repository.
- Replaces vague "governance exists" and "payload owns state logic" wording with concrete operational language.
- Adds tactical ConfigMgr, reboot, secrets, version control, linting, and agentic-workflow guidance.
- Converts the extended Q&A material into appendix-style reference slides without graphic requirements.

## Feedback Integration Matrix

| Feedback Theme | Treatment | Primary Slides |
| --- | --- | --- |
| Latest DSC v3 release needs visibility | Added a current stable release slide with v3.2.0 GA features, support posture, and deck-freeze check. | 7, 50 |
| DSC v3 and PowerShell relationship needs source-backed explanation | Added a dense slide stating ownership, dependency boundary, Rust implementation signal, adapters, and PSDSC distinction. | 8-9 |
| Evidence collection needs to be established and demonstrated | Introduced evidence as a named output model before the demo and revisited it during demo inspection and appendix schema. | 18, 25, 40, 52 |
| DSC executable distribution must be explicit | Added a bundle distribution slide and tied every execution plane to a pinned local `dsc` binary or approved lab-latest mode. | 18, 20, 53 |
| YAML and JSON support needs examples and a researched opinion | Added side-by-side examples and a practical rule: YAML for human authoring, JSON for generated artifacts, tests, and automation output. | 11, 51 |
| Technical repo vision was unclear | Added ProStateKit repo architecture, wrapper flow, stable inputs, validation, and agentic workflow slides. | 19-32 |
| Wrapper narrative did not connect to detect/remediate/evidence slides | Rebuilt detect, remediate, exit, and evidence slides around the wrapper contract instead of raw DSC command names alone. | 21-27 |
| Test environments need latest DSC version support | Added a lab-latest runtime mode in deck notes and made it a technical-spec requirement. | 18, 20, 53 |
| Slide 10 needed native-first rationale | Reframed native-first around supportability, least moving parts, built-in reporting, and operational ownership. | 13 |
| SSH, PSExec, and CI needed clearer positioning | Kept them as reach mechanisms or lab tools, not the recommended fleet pattern for the core demo. | 15 |
| macOS examples needed inclusion | Added native-first macOS examples and bounded DSC v3 experimentation language. | 17, 62 |
| Slides 31-45 needed demo-guide integration | Compressed the demo into a coherent runbook-backed sequence with proof goals, expected outputs, and fallback artifacts. | 34-43 |
| ConfigMgr slide needed a playbook | Added a tactical conversion slide and appendix checklist. | 45, 55 |
| Reboot ownership needed clarity | Added a slide that separates DSC state assessment from execution-plane restart policy and notes `_rebootRequested` removal. | 46, 56 |
| Q&A deep dives should become appendix material | Converted extended Q&A topics into reference slides. | 50-65 |

## Research Baseline

This draft uses the following source-backed claims as of 2026-05-03:

- DSC v3.2.0 is the current stable release announced on 2026-04-29. Source: [Announcing Microsoft Desired State Configuration v3.2.0](https://devblogs.microsoft.com/powershell/announcing-dsc-v3-2-0/).
- The PowerShell/DSC GitHub repository marks `v3.2.0` as the latest release and publishes release artifacts. Source: [PowerShell/DSC releases](https://github.com/PowerShell/DSC/releases).
- Microsoft describes DSC as a standalone command-line application that runs on Linux, macOS, and Windows without external dependencies and differs from PowerShell DSC. Source: [Microsoft Desired State Configuration overview](https://learn.microsoft.com/en-us/powershell/dsc/overview?view=dsc-3.0).
- The PowerShell/DSC repository is the DSC v3 project and is primarily Rust by GitHub language statistics. Source: [PowerShell/DSC repository](https://github.com/PowerShell/DSC).
- DSC configuration documents are YAML or JSON files containing a single object with `$schema`, `resources`, and optional properties. Source: [DSC configuration documents](https://learn.microsoft.com/en-us/powershell/dsc/concepts/configuration-documents/overview?view=dsc-3.0).
- `dsc config test` validates desired state; `dsc config set` enforces desired state; both can emit JSON, pretty JSON, or YAML. Sources: [dsc config test](https://learn.microsoft.com/en-us/powershell/dsc/reference/cli/config/test?view=dsc-3.0), [dsc config set](https://learn.microsoft.com/en-us/powershell/dsc/reference/cli/config/set?view=dsc-3.0).
- DSC command exit codes are runtime semantics, not a complete compliance verdict by themselves. Source: [dsc CLI reference](https://learn.microsoft.com/en-us/powershell/dsc/reference/cli/?view=dsc-3.0).
- Intune Remediations runs remediation when detection exits `1`, limits output to 2,048 characters, and says not to put reboot commands or sensitive information in detection/remediation scripts. Source: [Intune Remediations](https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations).
- Configuration Manager applications use content, detection methods, return codes, and reboot behavior that differ from Intune Remediations. Source: [Create applications in Configuration Manager](https://learn.microsoft.com/mem/configmgr/apps/deploy-use/create-applications).
- Configuration Manager compliance settings support discovery and remediation scripts through `Set-CMComplianceSettingScript`. Source: [Set-CMComplianceSettingScript](https://learn.microsoft.com/en-us/powershell/module/configurationmanager/set-cmcompliancesettingscript?view=sccm-ps).

## Dependency Markers

Use these markers in slide validation notes and asset requirements:

- **[RESEARCHED]** Claim is supported by primary or product-owner documentation as of 2026-05-03.
- **[TECHSPEC]** Content depends on [ProStateKit.md](ProStateKit.md) staying aligned with the deck.
- **[REPO]** Content depends on a built ProStateKit repository, real file names, and real commands.
- **[LAB]** Content depends on endpoint, Intune, ConfigMgr, or reboot lab validation.
- **[REHEARSAL]** Content depends on captured demo output, screenshots, timing, and fallback artifacts.
- **[EVENT]** Content should be rechecked one week before deck freeze because release, product, or service behavior can change.

## Style Guide Interpretation

This deck keeps the v11 production schema with the following additions:

- Every implementation-heavy slide MUST name its dependency marker when it is not yet proven by code or lab output.
- Every demo slide MUST map to the future ProStateKit runbook section that proves the same point.
- Visible slide copy SHOULD avoid unsupported product claims. Speaker notes MAY name unverified ideas only as future work or open validation debt.
- The phrase "execution plane" remains the deck spine: Intune, ConfigMgr, Arc, Jamf, Scheduled Tasks, CI, PSExec, SSH, or another runner decides when, where, and under which identity work runs.
- The phrase "state engine" describes DSC v3 in this deck: DSC v3 defines, tests, sets, and emits structured results for correct state.

## Deck-Spec Markdown Template

Future deck specs SHOULD use this per-slide schema.

```text
### Slide NN - Slide Title

- **Timebox:** Start-End within session clock
- **Section:** Core | Appendix
- **Presenter:** Presenter name or role
- **Slide Job:** Orient | Define | Compare | Warn | Process | Evidence | Demo | Debrief | Takeaway | Reference
- **Archetype:** Cover | Audience check-in | Concept primer | Comparison | Matrix/table | Pipeline/spine | Section divider | Technical deep dive | Code/command | Demo guide | Demo fallback | Demo debrief | Key takeaways | Resources | Appendix
- **Main Takeaway:** One sentence the audience should retain
- **On-Slide Content:** Exact text or content blocks to place on the slide
- **Layout:** Composition, zones, hierarchy, and progressive build guidance
- **Visual / Evidence Object:** Diagram, screenshot, command block, table, or artifact to display
- **Speaker Notes:** Presenter narration intent, including what not to over-explain
- **Transition:** How this slide hands off to the next slide
- **Build / Animation:** None | Progressive reveal | Highlight | Demo switch
- **Asset Requirements:** Needed screenshot, icon, diagram, file path, or generated asset
- **Word Target:** Approximate on-slide word count
- **Validation Notes:** Claims that MUST be checked against research, demo output, or official docs
```

## Deck Overview

- **Deck Size:** 65 slides total.
- **Core Session:** Slides 1-49 cover the fixed 75-minute session.
- **Appendix:** Slides 50-65 provide Q&A, reference, and implementation backup.
- **Primary Narrative:** Script fatigue grows when endpoint automation runs without dependable proof around declared state, distribution, evidence, exits, reboots, secrets, validation, and safe reruns.
- **Repeating Language:** "The execution plane decides when and where. DSC v3 defines, tests, sets, and reports correct state."
- **Technical Repository Narrative:** ProStateKit is the companion repository. It packages a pinned DSC runtime, configuration documents, runner scripts, validation gates, evidence schema, Intune entry points, ConfigMgr entry points, and a runbook.
- **Demo Spine:** Deterministic Windows endpoint break/fix demo using ProStateKit Detect and Remediate modes, `dsc config test`, `dsc config set`, normalized JSON evidence, manifest validation, exit-code translation, and idempotence proof.

## Core Session Deck Spec

### Slide 01 - Cure Script Fatigue

- **Timebox:** 00:00-00:30
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Orient
- **Archetype:** Cover
- **Main Takeaway:** This session separates scheduling from endpoint state proof.
- **On-Slide Content:** "Cure Script Fatigue: Reliable Endpoint State with DSC v3" / "MMSMOA 2026" / "Execution planes run work. DSC v3 proves state."
- **Layout:** Full-bleed title slide with title, event label, and two-layer tagline.
- **Visual / Evidence Object:** Background two-layer diagram: execution plane above DSC v3 state engine.
- **Speaker Notes:** Open with the promise. Do not define DSC yet.
- **Transition:** Move from title to practical outcomes.
- **Build / Animation:** None
- **Asset Requirements:** Background diagram generated from the two-layer model.
- **Word Target:** Approx. 16 visible words
- **Validation Notes:** Session title MUST remain exact.

### Slide 02 - What You Will Walk Away With

- **Timebox:** 00:30-01:30
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Orient
- **Archetype:** Key takeaways
- **Main Takeaway:** The session promises an operating model, a wrapper contract, and a repository pattern.
- **On-Slide Content:** "A two-layer operating model: your management plane decides reach and schedule; DSC v3 evaluates state." / "A reusable wrapper contract for detect, remediate, evidence, exits, reboots, and safe reruns." / "A ProStateKit repository plan for packaging, validation, and version-controlled endpoint state."
- **Layout:** Three takeaway cards with restrained icons: plane, wrapper, repository.
- **Visual / Evidence Object:** Three-card row.
- **Speaker Notes:** Keep this as the promise slide. Avoid product-boundary caveats until the audience has the basic model.
- **Transition:** Ask the room whether they have seen the failure mode.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Takeaway icons.
- **Word Target:** Approx. 45 visible words
- **Validation Notes:** [TECHSPEC] ProStateKit wording MUST remain aligned with the technical spec.

### Slide 03 - Show of Hands

- **Timebox:** 01:30-02:15
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Calibrate
- **Archetype:** Audience check-in
- **Main Takeaway:** The room already knows why script-only endpoint operations are fragile.
- **On-Slide Content:** "Show of hands: have you ever shipped a remediation script that reported success while the endpoint stayed wrong?" / "Have you ever needed proof, but the only answer was 'the script said it ran'?"
- **Layout:** Large question with two compact prompts.
- **Visual / Evidence Object:** Raised-hand icon only.
- **Speaker Notes:** Pause for hands. Treat the response as shared context, not a punchline.
- **Transition:** Turn the response into the false-green failure mode.
- **Build / Animation:** None
- **Asset Requirements:** Hand icon.
- **Word Target:** Approx. 33 visible words
- **Validation Notes:** No product claims.

### Slide 04 - False Green: Success You Cannot Trust

- **Timebox:** 02:15-03:45
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Warn
- **Archetype:** Evidence setup
- **Main Takeaway:** The worst endpoint failures are the ones that look successful to the management plane.
- **On-Slide Content:** "False green means the management plane recorded success while the endpoint stayed wrong." / "The user still sees the problem. The audit still finds the drift. The engineer still has to prove what happened." / "The damage comes from confidence before proof."
- **Layout:** Left definition, right mock status row with green platform status and red endpoint state.
- **Visual / Evidence Object:** Mock compliance row clearly labeled "illustrative."
- **Speaker Notes:** Keep this structural. Do not blame one tool.
- **Transition:** Expand false green into script fatigue.
- **Build / Animation:** Highlight mismatch
- **Asset Requirements:** Mock status row.
- **Word Target:** Approx. 42 visible words
- **Validation Notes:** Mock data MUST be labeled illustrative unless replaced by real demo output.

### Slide 05 - Script Fatigue Is a Proof Problem

- **Timebox:** 03:45-05:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Hook
- **Archetype:** Problem statement
- **Main Takeaway:** Script fatigue comes from repeated automation runs that lack reliable proof of endpoint state.
- **On-Slide Content:** "Endpoint teams already have scripts." / "They need a dependable way to prove desired state, translate outcomes, preserve evidence, handle reboots, and rerun safely." / "When proof is weak, every platform has to trust a thin success signal and a few lines of output."
- **Layout:** Three stacked statements, with the proof sentence emphasized.
- **Visual / Evidence Object:** Proof checklist with state, exits, evidence, reboots, reruns.
- **Speaker Notes:** Set up DSC v3 as an answer to proof, not as a replacement for management planes.
- **Transition:** Introduce DSC v3.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Proof checklist diagram.
- **Word Target:** Approx. 43 visible words
- **Validation Notes:** Keep wording practitioner-first.

### Slide 06 - DSC v3: The Short Technical Primer

- **Timebox:** 05:00-06:30
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Define
- **Archetype:** Concept primer
- **Main Takeaway:** DSC v3 is a standalone cross-platform command-line runtime for declared state, resource operations, and structured results.
- **On-Slide Content:** "DSC v3 is a standalone cross-platform CLI for Desired State Configuration." / "It evaluates JSON or YAML configuration documents, invokes resources, tests desired state, sets state when asked, and emits structured output." / "It runs as a command, so another tool still decides when and where it executes."
- **Layout:** Definition at top, three pillars below: document, resources, output.
- **Visual / Evidence Object:** Center `dsc` block connected to config, resources, structured result.
- **Speaker Notes:** Do not mention PSDSC here. This slide is the v3 definition only.
- **Transition:** Ground the audience in the current release.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** DSC v3 CLI concept diagram.
- **Word Target:** Approx. 48 visible words
- **Validation Notes:** [RESEARCHED] Aligns with Microsoft DSC overview and GitHub README.

### Slide 07 - DSC v3.2.0 Is the Current Stable Baseline

- **Timebox:** 06:30-08:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Define
- **Archetype:** Technical deep dive
- **Main Takeaway:** The deck and demo should pin to DSC v3.2.0 unless a later patch is selected and retested.
- **On-Slide Content:** "Current baseline for this draft: DSC v3.2.0 GA, announced April 29, 2026." / "What changed: built-in Windows resources, version pinning, richer expressions, custom functions, adapter improvements, secret extension capability, discovery extension work, and experimental Bicep integration over gRPC." / "Demo rule: pin the runtime; retest before changing it."
- **Layout:** Dense release card with "current stable," "what changed," and "demo implication."
- **Visual / Evidence Object:** Small release timeline: v3.0 GA, v3.1 GA, v3.2 GA.
- **Speaker Notes:** Do not turn this into a release-notes tour. Use it to justify pinning and the new version slide requested in feedback.
- **Transition:** Clarify how DSC v3 relates to PowerShell before comparing mental models.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Release timeline.
- **Word Target:** Approx. 55 visible words
- **Validation Notes:** [RESEARCHED] [EVENT] Recheck PowerShell/DSC releases one week before deck freeze.

### Slide 08 - DSC v3 and PowerShell: Same Ecosystem, Different Product

- **Timebox:** 08:00-10:15
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Define
- **Archetype:** Technical deep dive
- **Main Takeaway:** DSC v3 is owned in the PowerShell ecosystem, but it is not PowerShell DSC and does not require PowerShell to run.
- **On-Slide Content:** "Product home: PowerShell/DSC repository and PowerShell Team release posts." / "Runtime: standalone `dsc` executable; the open-source repo is primarily Rust." / "Dependency boundary: DSC v3 does not depend on PowerShell, Windows PowerShell, or the PSDesiredStateConfiguration module." / "Interop boundary: DSC v3 can invoke PowerShell DSC resources through adapter resources when PowerShell is present." / "Practical point: PowerShell is an integration path, not the required engine."
- **Layout:** Dense two-column relationship map: "owned by PowerShell team" and "not PowerShell DSC."
- **Visual / Evidence Object:** Relationship diagram with product ownership, runtime dependency, resource adapter.
- **Speaker Notes:** This is the requested technical clarification. Say "different product" plainly. Do not imply the PowerShell team is uninvolved.
- **Transition:** Now that the relationship is clear, explain old DSC naming carefully.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Relationship diagram.
- **Word Target:** Approx. 69 visible words
- **Validation Notes:** [RESEARCHED] Uses Microsoft DSC overview, PowerShell/DSC README, and release-post ownership context.

### Slide 09 - PSDSC Means the Older PowerShell DSC Line

- **Timebox:** 10:15-11:15
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Compare
- **Archetype:** Comparison
- **Main Takeaway:** PSDSC is technically useful shorthand when it means PowerShell Desired State Configuration v1.1/v2.
- **On-Slide Content:** "Use PSDSC carefully: Microsoft release language uses PSDSC for PowerShell Desired State Configuration v1.1 and v2." / "That older mental model includes MOF compilation, Local Configuration Manager settings, push or pull workflows, and pull-server operations." / "DSC v3 keeps desired-state thinking and changes the operating shape: CLI, JSON/YAML documents, resource adapters, and structured output."
- **Layout:** Two-column comparison: "PSDSC mental model" and "DSC v3 operating shape."
- **Visual / Evidence Object:** Compact comparison matrix.
- **Speaker Notes:** Confirm the name without overusing it. The goal is disambiguation, not nostalgia.
- **Transition:** Show the shape of a DSC v3 configuration document.
- **Build / Animation:** None
- **Asset Requirements:** Comparison matrix.
- **Word Target:** Approx. 56 visible words
- **Validation Notes:** [RESEARCHED] Confirmed by DSC v3.0 release terminology.

### Slide 10 - A Configuration Document Declares Correct State

- **Timebox:** 11:15-12:45
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Define
- **Archetype:** Concept primer
- **Main Takeaway:** A DSC v3 configuration document is data that names resource instances and their desired properties.
- **On-Slide Content:** "A DSC v3 configuration document is a JSON or YAML object." / "It includes `$schema`, a `resources` collection, and optional metadata, parameters, variables, and directives." / "Each resource instance has a name, type, and properties that describe the desired state." / "DSC validates the document, invokes resources, and returns structured results."
- **Layout:** Three labeled blocks: schema and directives, resources, properties.
- **Visual / Evidence Object:** Simplified object diagram.
- **Speaker Notes:** This replaces the old slide 8 location after the PowerShell relationship slide.
- **Transition:** Clarify YAML and JSON authoring tradeoffs.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Configuration object diagram.
- **Word Target:** Approx. 52 visible words
- **Validation Notes:** [RESEARCHED] Align with DSC configuration document docs.

### Slide 11 - YAML for Humans, JSON for Machines

- **Timebox:** 12:45-14:15
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Compare
- **Archetype:** Code/command
- **Main Takeaway:** DSC accepts YAML and JSON, but the repository should use each format for the job it is best at.
- **On-Slide Content:** "Same idea, two encodings." / "YAML authoring example: `$schema`, `resources`, `name`, `type`, `properties` with readable indentation." / "JSON generated example: the same object in explicit braces and arrays." / "Recommendation: author reviewable examples in YAML, generate or test canonical JSON when machines need strict comparison, and parse DSC command output as JSON."
- **Layout:** Side-by-side small code excerpts with a bottom recommendation strip.
- **Visual / Evidence Object:** YAML excerpt on left, JSON excerpt on right, plus "Use when..." labels.
- **Speaker Notes:** Be precise: do not claim YAML is inherently faster or slower. The performance point is not researched enough for the stage. The practical difference is authoring readability versus strict machine handling.
- **Transition:** Introduce the four DSC moves used by the wrapper.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Short YAML and JSON excerpts from final ProStateKit samples.
- **Word Target:** Approx. 56 visible words excluding code
- **Validation Notes:** [RESEARCHED] [REPO] Final examples MUST use actual ProStateKit config files.

### Slide 12 - The Four DSC v3 Moves We Need

- **Timebox:** 14:15-15:15
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Define
- **Archetype:** Concept primer
- **Main Takeaway:** Endpoint remediation only needs four DSC v3 moves: define, test, set, and parse.
- **On-Slide Content:** "Define: describe desired endpoint state in a DSC v3 configuration document." / "Test: run `dsc config test` to compare actual state with desired state." / "Set: run `dsc config set` to converge state when remediation is required." / "Parse: consume structured output instead of trusting the process exit code alone."
- **Layout:** Four-step row with command names under steps two and three.
- **Visual / Evidence Object:** Define, test, set, parse process strip.
- **Speaker Notes:** Emphasize that this is a minimal operating set, not a complete DSC tutorial.
- **Transition:** Position DSC v3 against native controls.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Four-step process strip.
- **Word Target:** Approx. 50 visible words
- **Validation Notes:** [RESEARCHED] Commands and parse warning align with DSC CLI docs.

### Slide 13 - Native First, DSC When State Needs Proof

- **Timebox:** 15:15-16:45
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Position
- **Archetype:** Comparison
- **Main Takeaway:** Native controls stay first because they reduce moving parts; DSC v3 is for state that needs reviewable definition, test/set behavior, and evidence.
- **On-Slide Content:** "Use native controls when they directly express the requirement: Settings Catalog, CSPs, compliance policies, security baselines, ConfigMgr baselines, Jamf policies, Apple DDM, or platform controls." / "Why: fewer moving parts, first-party reporting, supportable ownership, and less custom code." / "Use DSC v3 when state needs code-reviewed definition, repeatable test and set behavior, structured output, idempotent reruns, and durable evidence."
- **Layout:** Left "native first" criteria, right "DSC v3 fit" criteria.
- **Visual / Evidence Object:** Decision scale with native controls first, DSC v3 for proof-heavy gaps.
- **Speaker Notes:** This is the "why" requested in feedback. The answer is operational simplicity and ownership, not anti-DSC caution.
- **Transition:** Move to the two-layer model.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Decision scale diagram.
- **Word Target:** Approx. 63 visible words
- **Validation Notes:** MUST avoid replace-language.

### Slide 14 - The Handoff That Prevents False Green

- **Timebox:** 16:45-18:30
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Model
- **Archetype:** Pipeline/spine
- **Main Takeaway:** Reliability comes from a clear handoff between the tool that runs work and the payload that proves state.
- **On-Slide Content:** "The execution plane starts the run: target, schedule, identity, transport, and portal status." / "The DSC v3 payload proves state: configuration document, test result, set result, and structured resource output." / "The wrapper is the handoff: choose mode, invoke DSC, parse output, write evidence, and return the plane-specific result."
- **Layout:** Three-layer handoff diagram: plane, wrapper, DSC payload.
- **Visual / Evidence Object:** Recurring deck spine.
- **Speaker Notes:** This is the central model. Return to it during Intune, ConfigMgr, and demo slides.
- **Transition:** Define what execution planes really own.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Recurring spine diagram.
- **Word Target:** Approx. 54 visible words
- **Validation Notes:** This diagram SHOULD become the deck's recurring spine.

### Slide 15 - The Execution Plane Owns Reach and Context

- **Timebox:** 18:30-20:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Define
- **Archetype:** Technical deep dive
- **Main Takeaway:** The runner decides targeting, cadence, identity, transport, and reporting.
- **On-Slide Content:** "Execution plane examples: Intune, ConfigMgr, Arc, Jamf, Scheduled Tasks, CI, PSExec, SSH, or another runner." / "Fleet pattern: Intune, ConfigMgr, Arc, Jamf, or another managed plane owns assignment and reporting." / "Operator reach: PSExec or SSH may be useful in labs, break-glass, or troubleshooting, but they are not the core fleet story." / "CI proves the bundle before upload; it does not manage endpoints by itself."
- **Layout:** Three buckets: fleet planes, operator reach, CI validation.
- **Visual / Evidence Object:** Responsibility table.
- **Speaker Notes:** This resolves the SSH/PSExec feedback. Keep PSExec and SSH as reach methods, not endorsements for daily endpoint management.
- **Transition:** Define what DSC v3 payload owns.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Responsibility table.
- **Word Target:** Approx. 66 visible words
- **Validation Notes:** Vendor logos require approval if used.

### Slide 16 - State Logic Is Defined in the DSC v3 Payload

- **Timebox:** 20:00-21:15
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Define
- **Archetype:** Technical deep dive
- **Main Takeaway:** The DSC v3 payload describes correct state and reports the outcome; deployment orchestration stays with the plane.
- **On-Slide Content:** "State logic is defined in the DSC v3 payload." / "The payload declares what correct looks like, tests whether the endpoint matches it, attempts convergence when asked, and emits structured output." / "The execution plane still owns assignment, scheduling, user impact, portal status, and restart policy."
- **Layout:** Clear split diagram: payload state logic versus plane operations.
- **Visual / Evidence Object:** Responsibility split.
- **Speaker Notes:** This directly replaces confusing "payload owns state logic" wording with plain language.
- **Transition:** Show how the model travels across platforms.
- **Build / Animation:** None
- **Asset Requirements:** Split diagram.
- **Word Target:** Approx. 43 visible words
- **Validation Notes:** No claim that other products use DSC v3 internally.

### Slide 17 - The Pattern Travels, the Runner Rules Change

- **Timebox:** 21:15-22:45
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Bridge
- **Archetype:** Comparison
- **Main Takeaway:** The same state-and-evidence idea can travel, but each platform still has its own packaging and reporting rules.
- **On-Slide Content:** "Windows endpoint: Intune or ConfigMgr runs the wrapper; DSC v3 tests and sets state." / "Windows Server or Linux: Arc, Azure Machine Configuration, ConfigMgr, CI, SSH, or Scheduled Tasks may fit depending on governance." / "macOS: stay native-first with Apple MDM/DDM, Jamf, Homebrew Bundle, nix-darwin, or Home Manager; DSC v3 is only credible when the runner, resource, and evidence path are proven." / "Same idea. Different packaging, identity, exits, logs, and reporting."
- **Layout:** Platform rows with execution-plane examples and one caution column.
- **Visual / Evidence Object:** Platform matrix.
- **Speaker Notes:** Use simple language. Do not promise cross-platform parity.
- **Transition:** Move from platform model to distribution mechanics.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Platform matrix.
- **Word Target:** Approx. 78 visible words
- **Validation Notes:** [RESEARCHED] [LAB] macOS DSC claims require proof before becoming core guidance.

### Slide 18 - The DSC Executable Is a Dependency You Must Distribute

- **Timebox:** 22:45-24:15
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Define
- **Archetype:** Technical deep dive
- **Main Takeaway:** Endpoints need an available `dsc` executable; ProStateKit must make that dependency explicit and verifiable.
- **On-Slide Content:** "Do not assume `dsc.exe` is already on the endpoint." / "Production pattern: ship a pinned DSC release inside the bundle or install it as a managed prerequisite with version and hash validation." / "Evidence records the `dsc` path, version, source, and hash." / "Lab pattern: an explicit latest-runtime mode may be used for compatibility testing, never silently in production."
- **Layout:** Dependency flow: release artifact, bundle, endpoint path, evidence.
- **Visual / Evidence Object:** Bundle-to-endpoint distribution diagram.
- **Speaker Notes:** Make the requirement concrete. This is not an inbox Windows component assumption.
- **Transition:** Introduce ProStateKit as the repository that carries that bundle contract.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Distribution diagram.
- **Word Target:** Approx. 58 visible words
- **Validation Notes:** [RESEARCHED] [TECHSPEC] [REPO] Final runtime mode names MUST match ProStateKit.

### Slide 19 - Section: ProStateKit

- **Timebox:** 24:15-24:45
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Orient
- **Archetype:** Section divider
- **Main Takeaway:** The companion repository turns the model into a repeatable tool.
- **On-Slide Content:** "ProStateKit" / "A starter kit for versioned DSC v3 payloads, wrapper behavior, validation gates, and durable evidence."
- **Layout:** Sparse section divider with repository name and one sentence.
- **Visual / Evidence Object:** Repository spine icon.
- **Speaker Notes:** Explain that this is the named technical repo for the session.
- **Transition:** Show the repo architecture.
- **Build / Animation:** None
- **Asset Requirements:** ProStateKit wordmark or simple repository icon.
- **Word Target:** Approx. 19 visible words
- **Validation Notes:** [TECHSPEC] Repo name selected by user.

### Slide 20 - ProStateKit Packages the State Run

- **Timebox:** 24:45-26:15
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Define
- **Archetype:** Technical deep dive
- **Main Takeaway:** ProStateKit is a versioned bundle, not just a wrapper script.
- **On-Slide Content:** "Bundle contents: runner scripts, pinned DSC runtime, configuration documents, resources, schemas, manifest, tests, docs, and sample evidence." / "Manifest records version, source commit, runtime version, config hash, wrapper hash, resource versions, validation status, and supported planes." / "The execution plane receives one known artifact with known inputs."
- **Layout:** File tree left, manifest callouts right.
- **Visual / Evidence Object:** Planned repository tree and manifest card.
- **Speaker Notes:** Make clear that distribution and validation are part of the product, not separate chores.
- **Transition:** Walk through the wrapper flow.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** [REPO] Final file tree screenshot.
- **Word Target:** Approx. 50 visible words
- **Validation Notes:** [TECHSPEC] [REPO] File names MUST match final repository.

### Slide 21 - The Wrapper Turns Commands Into a Contract

- **Timebox:** 26:15-27:45
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Process
- **Archetype:** Pipeline/spine
- **Main Takeaway:** The wrapper is the contract that makes raw DSC operations usable by Intune, ConfigMgr, and humans.
- **On-Slide Content:** "Wrapper flow: validate inputs, verify bundle, select runtime, invoke DSC, capture raw output, normalize result, write evidence, translate exit, and return a short platform summary." / "Raw DSC output stays preserved." / "Consumers read the ProStateKit result schema."
- **Layout:** Horizontal flow with evidence and exit as final outputs.
- **Visual / Evidence Object:** Wrapper flow diagram.
- **Speaker Notes:** Tie this back to slides 19-22 from v11. The wrapper is not a decorative script; it is where proof becomes a platform result.
- **Transition:** Show the inputs that keep runs repeatable.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Wrapper flow diagram.
- **Word Target:** Approx. 41 visible words
- **Validation Notes:** [TECHSPEC] Wrapper steps MUST match ProStateKit.md.

### Slide 22 - Stable Inputs Make Runs Repeatable

- **Timebox:** 27:45-29:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Define
- **Archetype:** Code/command
- **Main Takeaway:** Stable, explicit inputs make the wrapper reusable and auditable.
- **On-Slide Content:** "`-Mode Detect|Remediate|ValidateBundle` chooses the operation." / "`-ConfigPath` points to the declared baseline." / "`-RuntimeMode PinnedBundle|InstalledPath|LabLatest` controls DSC version behavior." / "`-EvidenceRoot` chooses where proof is written." / "`-Plane Intune|ConfigMgr|Local` selects platform-facing output and exits."
- **Layout:** Parameter list with short definitions.
- **Visual / Evidence Object:** Command block and parameter callouts.
- **Speaker Notes:** Call out that latest runtime is an explicit test mode, not a production default.
- **Transition:** Clarify Detect without ambiguous "maps to" language.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** [REPO] Final command syntax screenshot.
- **Word Target:** Approx. 48 visible words
- **Validation Notes:** [TECHSPEC] [REPO] Parameter names MUST match implementation.

### Slide 23 - Detect Is a State Check

- **Timebox:** 29:00-30:15
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Process
- **Archetype:** Technical deep dive
- **Main Takeaway:** Detection means running a state test, saving evidence, and returning the plane-specific signal.
- **On-Slide Content:** "Detect mode runs `dsc config test`." / "The wrapper checks whether the endpoint is in the declared state, writes raw and normalized evidence, and returns the result expected by the execution plane." / "For Intune Remediations, compliant returns `0`; drift returns `1` so remediation can run." / "Runtime and parser failures fail closed."
- **Layout:** Detect flow with Intune exit behavior called out separately.
- **Visual / Evidence Object:** Detect pipeline: test, parse, evidence, exit.
- **Speaker Notes:** Avoid "Detect maps to..." without explanation. Define detect as wrapper mode, then name the DSC command.
- **Transition:** Define Remediate in the same language.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Detect pipeline diagram.
- **Word Target:** Approx. 58 visible words
- **Validation Notes:** [RESEARCHED] [TECHSPEC] [LAB] Plane-specific exit mappings require lab validation.

### Slide 24 - Remediate Sets State, Then Proves It

- **Timebox:** 30:15-31:30
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Process
- **Archetype:** Technical deep dive
- **Main Takeaway:** Remediation is a convergence attempt followed by verification, not a blind set operation.
- **On-Slide Content:** "Remediate mode runs `dsc config set`, then verifies with `dsc config test`." / "Success means the endpoint matches declared state after the set attempt." / "Evidence records the set output, verification output, normalized result, and final exit decision." / "If verification fails, the run stays red."
- **Layout:** Set, verify, evidence, exit pipeline.
- **Visual / Evidence Object:** Remediate pipeline.
- **Speaker Notes:** Define remediation in context: it is the wrapper's convergence mode and relates to DSC configuration application.
- **Transition:** Show exactly what evidence is collected.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Remediate pipeline diagram.
- **Word Target:** Approx. 50 visible words
- **Validation Notes:** [TECHSPEC] [REPO] Final wrapper MUST implement verify-after-set.

### Slide 25 - Evidence Is Collected on Every Run

- **Timebox:** 31:30-33:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Evidence
- **Archetype:** Technical deep dive
- **Main Takeaway:** Evidence is a first-class output, including successful runs.
- **On-Slide Content:** "Every run writes evidence, including green runs." / "Run folder: raw DSC stdout JSON, DSC stderr or trace log, DSC exit code, normalized result JSON, transcript or wrapper log, summary text, runtime metadata, bundle manifest snapshot, and optional reboot marker." / "Platform output carries a short summary; local evidence carries the full record."
- **Layout:** Evidence folder tree with callouts.
- **Visual / Evidence Object:** Planned evidence folder tree.
- **Speaker Notes:** This is where the talk proves that evidence collection is not hand-waved.
- **Transition:** Explain how evidence gets translated to platform status.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** [REPO] Final evidence folder screenshot.
- **Word Target:** Approx. 57 visible words
- **Validation Notes:** [TECHSPEC] [REPO] Artifact names MUST match implementation.

### Slide 26 - Exit Codes Translate Proof to the Platform

- **Timebox:** 33:00-34:15
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Define
- **Archetype:** Matrix/table
- **Main Takeaway:** The wrapper owns translation from DSC runtime results and compliance evidence to platform-specific behavior.
- **On-Slide Content:** "DSC exit `0` means the DSC command ran without runtime error; it does not prove every resource is compliant by itself." / "ProStateKit reads structured output first, then returns the platform-facing result." / "Intune example: `0` means compliant; `1` means drift detected; parser, runtime, or evidence failures fail closed." / "ConfigMgr uses a different detection and return-code surface."
- **Layout:** Two-row table: DSC runtime exit versus wrapper platform exit.
- **Visual / Evidence Object:** Exit translation table.
- **Speaker Notes:** This is a level-400 point. Do not rush it.
- **Transition:** Show why missing proof must fail closed.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Exit translation table.
- **Word Target:** Approx. 60 visible words
- **Validation Notes:** [RESEARCHED] [TECHSPEC] [LAB] ConfigMgr semantics require lab confirmation.

### Slide 27 - Missing Proof Fails Closed

- **Timebox:** 34:15-35:30
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Warn
- **Archetype:** Technical deep dive
- **Main Takeaway:** False-green prevention starts with rejecting unknown or incomplete evidence.
- **On-Slide Content:** "Fail-closed rule: no proof, no green." / "Capture raw output before interpreting it." / "Parse structured output with strict error handling." / "Validate expected fields, resource results, runtime metadata, and error state." / "Write normalized evidence before returning the platform result." / "Unknown shape, missing file, or hash mismatch returns red."
- **Layout:** Six-step fail-closed chain.
- **Visual / Evidence Object:** Parser resolution chain.
- **Speaker Notes:** Treat raw DSC output as an external contract and normalized ProStateKit output as the repo-owned contract.
- **Transition:** Move into secrets because evidence can create data exposure risk.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Parser resolution chain.
- **Word Target:** Approx. 52 visible words
- **Validation Notes:** [TECHSPEC] [REPO] Parser behavior and schema MUST be tested with fixtures.

### Slide 28 - Secrets Are Designed Before Evidence Capture

- **Timebox:** 35:30-36:45
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Guardrail
- **Archetype:** Technical deep dive
- **Main Takeaway:** Secret flow must be designed per resource and execution plane before the wrapper writes evidence.
- **On-Slide Content:** "Rule: no secret values in configuration documents, scripts, transcripts, raw DSC output, normalized evidence, screenshots, or platform output." / "Preferred patterns: platform identity, resource-native secure inputs, managed identity to Key Vault where available, local secure store only when noninteractive context is proven, and DSC `secret()` only after resource and extension support are tested." / "Evidence records references and success/failure, never values."
- **Layout:** Secret pattern decision ladder.
- **Visual / Evidence Object:** Decision ladder.
- **Speaker Notes:** Provide material resolution: choose the secret path before evidence capture and test under the actual run identity.
- **Transition:** Apply the same governance thinking to software installation.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Secret decision ladder.
- **Word Target:** Approx. 68 visible words
- **Validation Notes:** [RESEARCHED] [TECHSPEC] [LAB] SecretManagement and DSC `secret()` support MUST be validated before demo use.

### Slide 29 - Software State Needs a Real Owner

- **Timebox:** 36:45-38:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Bound
- **Archetype:** Comparison
- **Main Takeaway:** DSC can enforce declared package state only when source, version, detection, and ownership are governed.
- **On-Slide Content:** "Use app deployment and patching tools for broad software distribution, emergency updates, user experience, and restart orchestration." / "Use DSC v3 only when the requirement is declared package state with pinned source, deterministic detection, idempotent install behavior, exit translation, and durable evidence." / "The practical message: do not turn a DSC resource into an unmanaged package manager."
- **Layout:** Two columns: purpose-built platform fit and DSC state fit.
- **Visual / Evidence Object:** Software ownership matrix.
- **Speaker Notes:** Replace "governance exists" with concrete requirements: source, version, detection, owner, and evidence.
- **Transition:** Make version control a primary value proposition.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Software ownership matrix.
- **Word Target:** Approx. 58 visible words
- **Validation Notes:** Keep examples bounded and vendor-neutral.

### Slide 30 - Version Control Makes Endpoint State Reviewable

- **Timebox:** 38:00-39:15
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Define
- **Archetype:** Technical deep dive
- **Main Takeaway:** Version control is the difference between "a script ran" and "this reviewed state bundle ran."
- **On-Slide Content:** "Version control gives endpoint state a change history, review path, rollback point, and release identity." / "A pull request can show the baseline change, wrapper change, tests, generated bundle manifest, and sample evidence before endpoints ever see it." / "The bundle proves what ran by tying endpoint evidence back to a source commit and validated artifact."
- **Layout:** Git commit to bundle to endpoint evidence chain.
- **Visual / Evidence Object:** Traceability chain.
- **Speaker Notes:** Elevate version control as a key DSC v3 value: declared state is reviewable data.
- **Transition:** Explain linting and validation before deployment.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Traceability chain diagram.
- **Word Target:** Approx. 58 visible words
- **Validation Notes:** [TECHSPEC] Manifest traceability fields MUST match ProStateKit.md.

### Slide 31 - Linting Catches Problems Before Upload

- **Timebox:** 39:15-40:30
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Define
- **Archetype:** Technical deep dive
- **Main Takeaway:** Linting and tests are release gates that catch known mistakes before deployment.
- **On-Slide Content:** "Linting is an automated read of source, config, and doc files for known problems." / "It catches syntax errors, risky style, schema drift, inconsistent formatting, and predictable mistakes before endpoints receive the bundle." / "ProStateKit gates releases with PowerShell analysis, Pester tests, JSON/YAML parsing, DSC schema checks, Markdown linting, parser fixtures, redaction checks, and behavior tests."
- **Layout:** Plain definition at top, validation stack below.
- **Visual / Evidence Object:** Validation stack.
- **Speaker Notes:** Assume some attendees do not know CI/CD vocabulary. Define linting before naming tools.
- **Transition:** Show how agentic workflows sit on top of the same gates.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Validation stack diagram.
- **Word Target:** Approx. 61 visible words
- **Validation Notes:** [TECHSPEC] [REPO] Final tool list MUST match repository.

### Slide 32 - Agents Can Accelerate Changes, CI Owns the Gate

- **Timebox:** 40:30-41:45
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Process
- **Archetype:** Pipeline/spine
- **Main Takeaway:** Agentic workflows can help evolve the bundle when validation, review, and evidence remain non-negotiable.
- **On-Slide Content:** "Agentic workflow: issue, branch, proposed change, local test, pull request, CI validation, human review, bundle build, lab run, evidence capture." / "Agents can draft wrapper changes, config examples, tests, docs, and review debt fixes." / "CI is the hard stop. Humans own correctness, safety, and production rollout."
- **Layout:** GitHub workflow pipeline with CI gate highlighted.
- **Visual / Evidence Object:** Agentic closed-loop pipeline.
- **Speaker Notes:** Do not overpromise autonomous production changes. The repo is built so agents can work inside guardrails.
- **Transition:** Prove the bundle locally before the live demo.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Agentic workflow diagram.
- **Word Target:** Approx. 52 visible words
- **Validation Notes:** [TECHSPEC] Agent loop MUST match ProStateKit.md.

### Slide 33 - Local Preflight Proves the Bundle

- **Timebox:** 41:45-43:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Evidence
- **Archetype:** Code/command
- **Main Takeaway:** The same payload should pass a clean local preflight before any management plane runs it.
- **On-Slide Content:** "Preflight sequence: validate manifest, verify hashes, confirm `dsc --version`, parse YAML and JSON configs, run fixture tests, run detect against known-good state, introduce deterministic drift, run detect red, run remediate green, run detect again." / "The bundle is not uploadable until preflight passes."
- **Layout:** Numbered preflight checklist with expected colors.
- **Visual / Evidence Object:** Preflight command output screenshot after repository exists.
- **Speaker Notes:** Tie preflight to the demo runbook.
- **Transition:** Move into the live demo section.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** [REPO] [REHEARSAL] Preflight screenshot.
- **Word Target:** Approx. 47 visible words
- **Validation Notes:** [TECHSPEC] [REPO] Commands MUST match final runbook.

### Slide 34 - Section: Live Demo

- **Timebox:** 43:00-43:30
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Orient
- **Archetype:** Section divider
- **Main Takeaway:** The talk shifts from pattern to proof.
- **On-Slide Content:** "Live Demo" / "Break a Windows endpoint. Detect drift. Repair it. Prove it."
- **Layout:** Sparse divider.
- **Visual / Evidence Object:** Demo icon and recurring spine.
- **Speaker Notes:** Keep this short.
- **Transition:** Show the demo guide.
- **Build / Animation:** None
- **Asset Requirements:** Demo divider.
- **Word Target:** Approx. 12 visible words
- **Validation Notes:** None.

### Slide 35 - Demo Guide: Six Proof Points

- **Timebox:** 43:30-45:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Demo guide
- **Archetype:** Demo guide
- **Main Takeaway:** The demo is a runbook with known proof points, not a loose terminal walkthrough.
- **On-Slide Content:** "1. Verify bundle and runtime." / "2. Run known-good Detect and inspect green evidence." / "3. Introduce deterministic drift." / "4. Run Detect and show red is correct." / "5. Run Remediate and verify after set." / "6. Run final Detect and inspect durable evidence."
- **Layout:** Six-step demo map with proof output under each step.
- **Visual / Evidence Object:** Demo runbook roadmap.
- **Speaker Notes:** This integrates the previous many demo slides into one coherent guide.
- **Transition:** Show the fixed variables that make the demo safe.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** [REPO] Final runbook step names.
- **Word Target:** Approx. 42 visible words
- **Validation Notes:** [TECHSPEC] [REHEARSAL] Steps MUST match runbook.

### Slide 36 - Demo Proof Targets

- **Timebox:** 45:00-46:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Demo guide
- **Archetype:** Demo guide
- **Main Takeaway:** The demo has known variables and a fixed proof target.
- **On-Slide Content:** "Target: controlled Windows endpoint." / "Baseline: local group membership, LLMNR-related registry state, and a demo-owned marker file." / "Controls: pinned DSC runtime, fixed config, deterministic break script, local evidence root, captured fallback artifacts." / "Proof target: endpoint state, DSC result, wrapper result, and evidence agree."
- **Layout:** Four cards: target, baseline, controls, proof.
- **Visual / Evidence Object:** Demo target table.
- **Speaker Notes:** Keep the baseline small so the audience can see the state transition.
- **Transition:** Run known-good detection.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** [REPO] Baseline file names and endpoint screenshots.
- **Word Target:** Approx. 53 visible words
- **Validation Notes:** [LAB] LLMNR resource behavior and registry value type MUST be validated.

### Slide 37 - Known-Good Detect Produces Inspectable Green

- **Timebox:** 46:00-50:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Demo
- **Archetype:** Code/command
- **Main Takeaway:** The first green is trustworthy because evidence proves the endpoint matched declared state.
- **On-Slide Content:** "`Invoke-ProStateKit.ps1 -Mode Detect -Plane Local -ConfigPath .\\configs\\baseline.dsc.yaml`" / "Expected result: exit `0`, compliant normalized result, raw DSC output captured, manifest recorded, and evidence folder created." / "Green is earned by a state test, not assumed from a script exit."
- **Layout:** Command at top, expected result bullets below, evidence screenshot area.
- **Visual / Evidence Object:** Terminal and evidence folder screenshot.
- **Speaker Notes:** Show `dsc --version` or evidence metadata if time allows.
- **Transition:** Break the machine in a deterministic way.
- **Build / Animation:** Demo switch
- **Asset Requirements:** [REPO] [REHEARSAL] Actual command and screenshot.
- **Word Target:** Approx. 46 visible words
- **Validation Notes:** [REPO] Command path MUST match final runner.

### Slide 38 - Deterministic Drift Makes Red Meaningful

- **Timebox:** 50:00-54:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Demo
- **Archetype:** Demo guide
- **Main Takeaway:** Drift should be repeatable, reversible, and visible enough for the audience to understand.
- **On-Slide Content:** "Break script changes only demo-owned or lab-safe state." / "Drift examples: local group membership, LLMNR-related registry value, marker file content." / "Expected result: the endpoint is wrong in known ways and can be restored by the baseline." / "The break script is part of the runbook, not improvised."
- **Layout:** Before/after state markers for the three resources.
- **Visual / Evidence Object:** Drift state table.
- **Speaker Notes:** Do not make the registry or security setting the star. The proof path is the star.
- **Transition:** Run detect against drift.
- **Build / Animation:** Demo switch
- **Asset Requirements:** [REPO] Break script and screenshots.
- **Word Target:** Approx. 54 visible words
- **Validation Notes:** [LAB] Break script MUST be idempotent and reversible.

### Slide 39 - Detect Drift: Red Is Correct

- **Timebox:** 54:00-59:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Demo
- **Archetype:** Code/command
- **Main Takeaway:** A failed detection is the correct result when endpoint state is wrong.
- **On-Slide Content:** "Run Detect after the scripted break." / "Expected result: non-compliant normalized result, Intune-style drift exit available, raw DSC output captured, and resource-level drift recorded." / "This red result prevents false green. It refuses to tell the plane the endpoint is healthy before state is proven."
- **Layout:** Command and red result on left, evidence excerpt on right.
- **Visual / Evidence Object:** `wrapper.result.json` excerpt showing noncompliance.
- **Speaker Notes:** Show the first actionable drift field and evidence path.
- **Transition:** Remediate and verify.
- **Build / Animation:** Demo switch
- **Asset Requirements:** [REPO] [REHEARSAL] Noncompliant evidence screenshot.
- **Word Target:** Approx. 50 visible words
- **Validation Notes:** [REHEARSAL] Exit and evidence fields MUST be captured.

### Slide 40 - Remediate Writes Set and Verification Evidence

- **Timebox:** 59:00-64:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Demo
- **Archetype:** Code/command
- **Main Takeaway:** Remediation returns green only after set and verification agree.
- **On-Slide Content:** "`Invoke-ProStateKit.ps1 -Mode Remediate -Plane Local -ConfigPath .\\configs\\baseline.dsc.yaml`" / "Expected result: set runs, verification test passes, exit `0` returns, and both set and verification evidence are written." / "The wrapper returns success because the post-set test proves convergence."
- **Layout:** Command at top, set result and verification result side by side.
- **Visual / Evidence Object:** Evidence folder containing set and verification artifacts.
- **Speaker Notes:** Do not say remediation succeeded until verification passes.
- **Transition:** Prove rerun safety.
- **Build / Animation:** Demo switch
- **Asset Requirements:** [REPO] [REHEARSAL] Remediation evidence screenshot.
- **Word Target:** Approx. 47 visible words
- **Validation Notes:** [REPO] Verification-after-set MUST be implemented.

### Slide 41 - Idempotence Proves Safe Reruns

- **Timebox:** 64:00-67:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Demo
- **Archetype:** Code/command
- **Main Takeaway:** A reliable payload can run repeatedly without creating new drift.
- **On-Slide Content:** "Run Detect one more time." / "Expected result: exit `0`, compliant normalized result, no corrective action required, and a new evidence record for the final pass." / "The second green matters because it proves repeated execution is safe."
- **Layout:** Final command and four proof signals.
- **Visual / Evidence Object:** Final detect evidence screenshot.
- **Speaker Notes:** This is the practical payoff for scheduled or recurring execution planes.
- **Transition:** Inspect the full evidence record.
- **Build / Animation:** Demo switch
- **Asset Requirements:** [REPO] [REHEARSAL] Final detect screenshot.
- **Word Target:** Approx. 40 visible words
- **Validation Notes:** [REHEARSAL] Final detect MUST be stable across rehearsals.

### Slide 42 - The Runbook Tells You What to Show

- **Timebox:** 67:00-68:30
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Evidence
- **Archetype:** Demo fallback
- **Main Takeaway:** The technical repository should produce a runbook that makes the demo repeatable and auditable.
- **On-Slide Content:** "Runbook outputs: step commands, expected exits, expected evidence files, screenshots to capture, fallback artifacts, reset procedure, and troubleshooting branches." / "If the live terminal fails, the proof path still exists in captured output." / "The goal is not a perfect demo. The goal is an inspectable proof path."
- **Layout:** Runbook checklist with fallback callout.
- **Visual / Evidence Object:** Runbook page screenshot after ProStateKit exists.
- **Speaker Notes:** This addresses the previous many demo slides by tying them to a repository output.
- **Transition:** Debrief the proof path.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** [REPO] [REHEARSAL] Final demo runbook.
- **Word Target:** Approx. 52 visible words
- **Validation Notes:** [TECHSPEC] [REPO] Runbook is required output of ProStateKit.

### Slide 43 - The Demo Proved Test, Set, Evidence

- **Timebox:** 68:30-70:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Debrief
- **Archetype:** Demo debrief
- **Main Takeaway:** The demo succeeded because every result moved through the same visible proof path.
- **On-Slide Content:** "Demo debrief: the endpoint changed because each step moved through the same proof path." / "Detect ran `dsc config test` and returned red when state was wrong." / "Remediate ran `dsc config set`, then verified with another test before returning green." / "Evidence captured both the raw DSC result and the ProStateKit decision."
- **Layout:** Four proof signals with checkmarks.
- **Visual / Evidence Object:** Endpoint, DSC, wrapper, evidence agreement row.
- **Speaker Notes:** Keep the debrief short. The audience just saw the proof.
- **Transition:** Bridge to Intune-specific constraints.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Agreement row.
- **Word Target:** Approx. 55 visible words
- **Validation Notes:** [REHEARSAL] Debrief MUST match actual demo behavior.

### Slide 44 - Intune Remediations Adds Specific Limits

- **Timebox:** 70:00-71:30
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Bridge
- **Archetype:** Technical deep dive
- **Main Takeaway:** Intune can run this pattern when the wrapper respects Intune-specific limits.
- **On-Slide Content:** "Intune Remediations can run the pattern when ProStateKit respects Intune's contract." / "Detection exit `1` triggers remediation." / "Output is limited to 2,048 characters, so portal output carries a short summary while local evidence carries the full record." / "Scripts should be UTF-8, and reboot commands do not belong in detection or remediation scripts."
- **Layout:** Intune contract checklist.
- **Visual / Evidence Object:** Intune limit card.
- **Speaker Notes:** Make this tactical and source-backed.
- **Transition:** Show the ConfigMgr conversion playbook.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Intune contract checklist.
- **Word Target:** Approx. 58 visible words
- **Validation Notes:** [RESEARCHED] [EVENT] Recheck Intune docs before final deck.

### Slide 45 - ConfigMgr Reuses the Payload and Changes the Wrapper Surface

- **Timebox:** 71:30-72:45
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Bridge
- **Archetype:** Technical deep dive
- **Main Takeaway:** ConfigMgr support is a wrapper and deployment-surface adaptation, not a new DSC payload.
- **On-Slide Content:** "Keep stable: DSC config, resources, manifest, evidence schema, parser, verify-after-set rule." / "Change for ConfigMgr: content distribution, install command, detection method, compliance discovery script, remediation script, run context, log location, return-code handling, and reboot behavior." / "Application deployment can place the bundle; compliance settings can discover and remediate state."
- **Layout:** Stable versus ConfigMgr-specific table.
- **Visual / Evidence Object:** ConfigMgr conversion checklist.
- **Speaker Notes:** This is the material answer requested for the prior empty callout. Stay honest that lab validation is still required.
- **Transition:** Discuss reboot ownership.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** ConfigMgr checklist.
- **Word Target:** Approx. 55 visible words
- **Validation Notes:** [RESEARCHED] [TECHSPEC] [LAB] ConfigMgr playbook MUST be validated before becoming prescriptive.

### Slide 46 - The Execution Plane Owns Reboots

- **Timebox:** 72:45-73:45
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Guardrail
- **Archetype:** Technical deep dive
- **Main Takeaway:** DSC can expose state and resource results, but restart policy belongs to the execution plane.
- **On-Slide Content:** "Reboots are state transitions with user impact." / "DSC assesses state and may expose reboot-related signals through resources or metadata, but the execution plane owns restart policy, user notification, maintenance windows, and retry cadence." / "ProStateKit records pre-reboot evidence, pending intent, operation ID, and next action." / "Do not depend on obsolete `_rebootRequested`; it was removed during the v3.2 preview cycle."
- **Layout:** Pre-reboot, plane restart, post-reboot verification flow.
- **Visual / Evidence Object:** Reboot responsibility flow.
- **Speaker Notes:** Be direct: do not reboot from Intune Remediations scripts. For ConfigMgr, return-code handling and client behavior must be tested.
- **Transition:** Park adjacent topics as future exploration.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Reboot flow diagram.
- **Word Target:** Approx. 67 visible words
- **Validation Notes:** [RESEARCHED] [TECHSPEC] [LAB] Reboot behavior MUST be validated per plane.

### Slide 47 - Future Exploration Starts After the Core Proof

- **Timebox:** 73:45-74:15
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Orient
- **Archetype:** Appendix
- **Main Takeaway:** Adjacent topics are important, but they should not dilute the core proof path.
- **On-Slide Content:** "Future exploration: deeper reboot orchestration, central reporting, Azure Machine Configuration packaging, resource gaps, software state, macOS boundaries, Linux/server variants, secrets extensions, and agent-assisted policy authoring." / "These are extensions of the proof model, not prerequisites for understanding it."
- **Layout:** Simple topic list, no graphics.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** This replaces the speaker-note-like Q&A slide from v11 with a clean future-opportunity frame.
- **Transition:** Land the takeaways.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 43 visible words
- **Validation Notes:** None.

### Slide 48 - Good Endpoint State Has Proof

- **Timebox:** 74:15-74:45
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Takeaway
- **Archetype:** Key takeaways
- **Main Takeaway:** The audience should leave with a concrete standard for endpoint state workflows.
- **On-Slide Content:** "Good endpoint state has declared state in version control." / "A pinned and verified runtime." / "Detect as a state test." / "Remediate as set plus verification." / "Evidence that survives portal output." / "Exit behavior the execution plane understands." / "A runbook that proves the pattern again next week."
- **Layout:** Seven compact checklist items.
- **Visual / Evidence Object:** Final proof checklist.
- **Speaker Notes:** Keep this crisp. This is the standard they can apply elsewhere.
- **Transition:** Give the Monday action.
- **Build / Animation:** Progressive reveal
- **Asset Requirements:** Final checklist.
- **Word Target:** Approx. 42 visible words
- **Validation Notes:** None.

### Slide 49 - Next Monday: Replace One Remediation Script With DSC

- **Timebox:** 74:45-75:00
- **Section:** Core
- **Presenter:** Frank
- **Slide Job:** Close
- **Archetype:** Key takeaways
- **Main Takeaway:** The audience can apply the pattern incrementally to one fragile remediation.
- **On-Slide Content:** "Next Monday: pick a remediation script to replace with DSC." / "Write down the desired state, the detection rule, the remediation action, the evidence you need afterward, and the exit behavior your execution plane expects." / "Then decide whether DSC v3 should own that state. Start with one proof path."
- **Layout:** Large action sentence plus small checklist.
- **Visual / Evidence Object:** Simple "one script" callout.
- **Speaker Notes:** This uses the requested phrasing and avoids scoping the takeaway to the demo scenario only.
- **Transition:** Hand to the existing Q&A slide or moderator.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 49 visible words
- **Validation Notes:** None.

## Appendix Deck Spec

### Slide 50 - Appendix: DSC v3.2.0 Release Notes to Recheck

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** Release-sensitive claims should be rechecked near deck freeze.
- **On-Slide Content:** "Recheck before final delivery: latest stable release, patch release availability, v3.3 previews, artifact hashes, built-in Windows resource list, `secret()` extension behavior, PowerShell adapter notes, and version-pinning syntax." / "Core demo should use a pinned stable runtime unless there is a deliberate lab-validated reason to change."
- **Layout:** Dense checklist.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** Use only if release questions come up.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 45 visible words
- **Validation Notes:** [EVENT] Recheck official release page.

### Slide 51 - Appendix: YAML and JSON Example Pair

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** The examples should use the same resource intent in both encodings.
- **On-Slide Content:** "Show the same baseline resource in YAML and JSON." / "Callouts: `$schema`, `resources`, `name`, `type`, `properties`, and version directive when used." / "Recommendation remains: YAML for human-reviewed samples, JSON for generated canonical artifacts and machine comparison, JSON output for wrapper parsing."
- **Layout:** Side-by-side code excerpts.
- **Visual / Evidence Object:** Final ProStateKit sample files.
- **Speaker Notes:** Keep this as a reference if the YAML/JSON question gets detailed.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** [REPO] Final YAML and JSON examples.
- **Word Target:** Approx. 43 visible words excluding code
- **Validation Notes:** [REPO] Examples MUST be generated from final configs.

### Slide 52 - Appendix: Normalized Evidence Schema

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** The normalized schema is the stable result shape consumers should inspect.
- **On-Slide Content:** "ProStateKit result fields: `schemaVersion`, `operationId`, `mode`, `plane`, `configPath`, `bundleVersion`, `bundleHash`, `runtimePath`, `runtimeVersion`, `startedAt`, `endedAt`, `durationMs`, `compliant`, `resources`, `reboot`, `exitDecision`, `evidencePath`, `errors`, `warnings`." / "Raw DSC output remains available, but automation reads normalized evidence."
- **Layout:** Dense schema field table.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** Explain that this is the repository-owned contract.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 49 visible words
- **Validation Notes:** [TECHSPEC] [REPO] MUST match final schema.

### Slide 53 - Appendix: Runtime Distribution Checklist

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** Runtime distribution is a package-management decision with evidence requirements.
- **On-Slide Content:** "Production options: bundle pinned DSC ZIP, deploy DSC as managed prerequisite, or validate an approved installed path." / "Test option: explicit `LabLatest` mode for compatibility testing with the latest stable runtime." / "Required evidence: path, version, source URL, expected hash, observed hash, selection mode, and validation result." / "No silent live download in production endpoint runs."
- **Layout:** Checklist.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** Use this to answer dependency distribution questions.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 58 visible words
- **Validation Notes:** [TECHSPEC] Runtime mode names MUST match ProStateKit.

### Slide 54 - Appendix: Intune Remediations Contract

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** Intune Remediations has a specific contract the wrapper must respect.
- **On-Slide Content:** "Detection script exit `1` triggers remediation." / "Output limit is 2,048 characters." / "Use UTF-8 scripts." / "Do not put reboot commands or sensitive information in detection or remediation scripts." / "Portal output should be a summary and evidence pointer; full proof stays local or moves through an explicitly approved reporting path."
- **Layout:** Reference checklist.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** Keep source-backed.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 51 visible words
- **Validation Notes:** [RESEARCHED] [EVENT] Recheck current Intune docs.

### Slide 55 - Appendix: ConfigMgr Conversion Checklist

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** ConfigMgr conversion requires adapting deployment, detection, remediation, return codes, and reporting.
- **On-Slide Content:** "1. Deploy bundle as Application or Package content." / "2. Detect bundle install by manifest version and hash." / "3. Use compliance discovery script to run Detect and return the expected data type." / "4. Use compliance remediation script to run Remediate." / "5. Configure run context, 64-bit behavior, log location, and client settings." / "6. Map return codes and reboot behavior where Application deployment is used." / "7. Preserve the same evidence schema."
- **Layout:** Numbered checklist.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** Stay clear that this is a technical playbook to validate, not a completed lab result yet.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 69 visible words
- **Validation Notes:** [TECHSPEC] [LAB] Must be reconciled after ConfigMgr implementation.

### Slide 56 - Appendix: Reboot Continuation Options

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** Continuation strategy depends on the execution plane guarantees.
- **On-Slide Content:** "Preferred: plane-managed restart and rerun, because the plane owns restart policy, user notification, maintenance windows, and retry cadence." / "Fallback: durable local pending state plus governed scheduled continuation when the plane lacks native continuation." / "Evidence records pre-reboot assessment, reason, marker path, operation ID, and post-reboot verification." / "No dependency on obsolete `_rebootRequested`."
- **Layout:** Two-option reference table.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** Mention scheduled-task fallback only with signing, TTL, cleanup, and audit proof.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 58 visible words
- **Validation Notes:** [RESEARCHED] [TECHSPEC] [LAB] Reboot behavior is plane-specific.

### Slide 57 - Appendix: Secrets Scenarios

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** Secret handling is a per-resource, per-plane design decision.
- **On-Slide Content:** "Scenario A: no secret required." / "Scenario B: platform identity supplies access." / "Scenario C: resource-native secure input handles the sensitive value." / "Scenario D: managed identity retrieves from Key Vault where available." / "Scenario E: local secure store works only after noninteractive context, ACLs, and prompting behavior are proven." / "Scenario F: DSC `secret()` is used only after extension and resource support are tested." / "Evidence never stores secret values."
- **Layout:** Scenario ladder.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** Use for security questions.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 74 visible words
- **Validation Notes:** [TECHSPEC] [LAB] Secrets support must be tested under actual run identity.

### Slide 58 - Appendix: Validation Commands Must Be Repeatable

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** The starter kit should have repeatable validation commands from a clean checkout.
- **On-Slide Content:** "Validation gates: PowerShell parse, PSScriptAnalyzer, Pester, Markdown lint, JSON parse, YAML parse, DSC schema validation, DSC fixture parsing, evidence schema validation, redaction checks, manifest hash validation, behavior tests, and package build verification." / "The exact commands must come from the final ProStateKit repository."
- **Layout:** Dense validation checklist.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** Define linting if this appendix is used with non-DevOps audiences.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 47 visible words
- **Validation Notes:** [REPO] Replace with actual commands after repo build.

### Slide 59 - Appendix: Agentic Workflow Guardrails

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** Agents are useful when the repository forces traceable changes, validation, and human review.
- **On-Slide Content:** "Agent-friendly loop: open issue, create branch, edit small scope, run tests, update docs, open pull request, respond to review, rerun CI, produce bundle, capture lab evidence." / "Guardrails: no secrets, no untrusted command execution, no hidden telemetry, no weakening security constraints, no green without evidence, no production rollout without human approval."
- **Layout:** Reference checklist.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** Keep this practical and aligned with repo instructions.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 58 visible words
- **Validation Notes:** [TECHSPEC] Agent workflow MUST align with repository governance.

### Slide 60 - Appendix: Azure Machine Configuration Boundary

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** Azure Machine Configuration belongs in the governance conversation, but it is not automatically the same local ProStateKit bundle.
- **On-Slide Content:** "Azure Machine Configuration can audit and configure OS settings through Azure and Arc governance paths." / "Use current terminology: Azure Machine Configuration, formerly Azure Policy Guest Configuration." / "Do not claim ProStateKit is a drop-in Machine Configuration package until one is built and tested." / "The useful comparison is operating model: assignment, evaluation, remediation, reporting, and evidence."
- **Layout:** Boundary card.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** Avoid overclaiming internal implementation details.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 58 visible words
- **Validation Notes:** [RESEARCHED] [LAB] Terminology and packaging must be revalidated.

### Slide 61 - Appendix: Server and Linux Keep Their Own Planes

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** Server and Linux targets can use the same questions while preserving their own execution planes.
- **On-Slide Content:** "Questions to reuse: What declares state? What tests state? What sets state? What captures evidence? What translates exits? What owns reboots? What owns reporting?" / "Windows Server and Linux may use Arc, Azure Machine Configuration, ConfigMgr, CI, SSH, systemd timers, or another governed runner." / "Do not imply the Windows endpoint bundle is universal without proof."
- **Layout:** Question list.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** Use this for cross-platform Q&A.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 59 visible words
- **Validation Notes:** [LAB] Cross-platform examples require implementation proof.

### Slide 62 - Appendix: macOS Stays Native-First

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** macOS management stays native-first unless a DSC v3 payload has credible proof.
- **On-Slide Content:** "macOS centers of gravity: Apple MDM/DDM, Jamf, Homebrew Bundle, nix-darwin, Home Manager, or internal tooling." / "DSC v3 can run on macOS, but that does not make it the default macOS management plane." / "A credible macOS story needs a runner, resources, identity model, packaging path, evidence model, and tested rollback."
- **Layout:** Native-first card.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** This satisfies the macOS feedback without moving the core demo away from Windows.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 58 visible words
- **Validation Notes:** [RESEARCHED] [LAB] No DSC-centered macOS claim without working proof.

### Slide 63 - Appendix: Software Installation Boundary

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** DSC can wrap package state only when detection, idempotence, governance, and evidence are real.
- **On-Slide Content:** "Appropriate: declared package presence, pinned source, internal feed, version floor, deterministic detection, idempotent install, explicit ownership, exit translation, and evidence capture." / "Wrong tool: emergency patching, arbitrary internet installs, user experience, broad app distribution, supersedence, and restart choreography." / "Use purpose-built app and patch platforms where they own the problem better."
- **Layout:** Fit and non-fit columns.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** This answers governance questions directly.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 55 visible words
- **Validation Notes:** Keep examples bounded.

### Slide 64 - Appendix: Resource Gaps Need a Fail-Closed Decision

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** Missing resource coverage is a design decision, not a reason to return false green.
- **On-Slide Content:** "Decision rule: use a DSC resource when it cleanly expresses state and supports test/set behavior." / "If no resource exists, wrap detection and remediation deliberately with the same evidence, redaction, idempotence, and fail-closed rules." / "Untestable state fails closed." / "A fragile custom wrapper can recreate the script fatigue DSC was meant to reduce."
- **Layout:** Decision rule card.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** This is useful for audience "what if no resource exists?" questions.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 56 visible words
- **Validation Notes:** Avoid claiming resource availability without validation.

### Slide 65 - Appendix: Open Review Debt

- **Timebox:** Appendix
- **Section:** Appendix
- **Presenter:** Either
- **Slide Job:** Reference
- **Archetype:** Appendix
- **Main Takeaway:** Anything not proven by ProStateKit remains visible review debt.
- **On-Slide Content:** "Open debt after this spec: final ProStateKit file names, commands, evidence schema, parser fixtures, Intune lab results, ConfigMgr lab results, reboot continuation behavior, secret flow validation, macOS examples, Azure Machine Configuration boundary, demo timing, and fallback screenshots." / "Do not generate final slides from unproven implementation details."
- **Layout:** Debt checklist.
- **Visual / Evidence Object:** None.
- **Speaker Notes:** This slide is for internal review and should likely be hidden before delivery.
- **Transition:** Appendix only.
- **Build / Animation:** None
- **Asset Requirements:** None.
- **Word Target:** Approx. 49 visible words
- **Validation Notes:** [TECHSPEC] [REPO] [LAB] Keep synchronized with [DSCv3-14a-next-steps.md](DSCv3-14a-next-steps.md).

## Slide Generation Notes

- The deck generator SHOULD treat this file as the revised content source of truth after ProStateKit technical specification review.
- Slides with [REPO], [LAB], or [REHEARSAL] markers MUST remain visually cautious until the technical repository, lab validation, and rehearsal artifacts exist.
- The first generated v14 draft SHOULD prioritize the recurring spine, dependency distribution diagram, evidence folder visuals, and demo runbook layout.
- Speaker notes SHOULD be generated from the `Speaker Notes` and `Transition` fields, then edited for spoken pacing.
- Screenshot placeholders MUST be replaced with ProStateKit rehearsal artifacts before final delivery.
- Appendix slides are intentionally reference-style and do not require custom graphics.
