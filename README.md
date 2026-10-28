# Handsel

Handsel helps multi-pet households log each animal's care rounds. Today is the care post: beckon one pet, then hand that pet the token to log its next owed routine. The live Today screen puts the token and its enabled Hand action beside the household's waiting pets. Pets, Routines, the care log, a handoff guide and Settings open as native sheets without a tab bar.

## Why a Post fold

`PostPhase` is an algebraic data type with `idle`, `beckoned(petID:)` and `shut`. `PostFold` reconstructs it for an Int YYYYMMDD daykey from the household's dated obligations and ordered marks. No phase, completed count or streak is stored separately. This fits a shared household: a care log must identify both the pet and its routine, and a token handed to the wrong pet must never fulfil care.

Commands produce a complete candidate HouseholdRecord plus an effect. Beckon seats one pet. Hand consumes its next undone routine in ascending order, breaking ties by stable routine UUID. A nonfinal Hand returns to Idle; the final Hand and its dependent ShutMark are one transaction. Hand to another active pet records MissMark without consuming the beckon. Hand while Idle or Shut, Beckon while Shut or already Beckoned, unknown pets and pets without owed care are refused. An empty household records Bare once per day and cannot complete a day.

Undo removes the latest HandMark whose round is still owed that day and its dependent Shut, then appends a new BeckonMark for that pet. A more recent archived log stays in history, so undoing a shut day always reopens an eligible round in Beckoned. If only archived care remains, Undo is unavailable. Both the native Hand control and a token drop resolved to a pet use `PostPresentation.hand`. This beckon-then-hand mechanic is the product's distinction; Today shows the mechanic itself, with Pets, Routines, Settings and history presented as sheets.

## Historical completeness

A dated obligation snapshot freezes each observed day's pet names, routine names, ownership and ordering. Later edits update only the current day's contract. Removed or inactive rounds with existing logs remain as archived entries in that day's snapshot. The fold retains their labels, HandMarks and event order for the care log, while owed totals, remaining work and completion exclude them. Removing or pausing the last active pet writes Bare in the same transaction, without requiring a subsequent command or reload. Previously observed days retain their original contract even after pets or routines are removed. Unobserved days and days with no owed routines are incomplete.

A day is complete if and only if every owed routine has its matching Pet's HandMark. ShutMark is an audit consequence, never a substitute for missing care. An edit that removes the last unfinished obligation also appends ShutMark in the same transaction, linked to the latest HandMark still owed today. The streak starts at today when complete, otherwise yesterday, and stops at the first incomplete or unobserved day. `PostCalendar` uses local start-of-day and Calendar day arithmetic across month, year, leap-day and DST boundaries.

## Persistence and presentation

`HouseholdStorage` is the single async seam. `HouseholdStore` is an actor with an explicit committed record. It stores versioned Codable data under `hns.household.v1` in UserDefaults and maintains an authoritative atomic document in Application Support. This satisfies the app-specific UserDefaults contract together with the specification's atomic file and recovery requirements. There are no RunRecord scores, networking clients, scanner imports or external dependencies.

Each commit creates the directory if necessary, atomically writes a validated previous-good `.backup`, then atomically replaces the complete primary document. UserDefaults mirrors the committed document. Every edit is eagerly awaited, so no debounce queue or termination hook is needed; `flush()` is available for inactive/background lifecycle calls. User records remain eligible for device backup. Cancellation is checked before committing, never after a durable write.

Decoding switches on schemaVersion and validates record identity and ownership. Corrupt/unsupported bytes are preserved in recovery copies. Load falls back to the previous good backup, then the UserDefaults copy, then empty state with an actionable recovery notice. Empty recovery cannot seed or overwrite damaged data; explicit reset or successful retry is required. Reset replaces both primary and backup with empty data while retaining the demo version marker to prevent reseeding after reset.

`@MainActor PostPresentation` exposes derived Today, Pets, Routines, Settings, history, onboarding and token state. It owns no background tasks. Views await its methods from view-owned tasks, refresh local day boundaries while active and flush on backgrounding. The presentation publishes the candidate only after persistence succeeds and invokes the injected success-feedback closure exactly once for a durable Hand. Miss, refusal, Beckon, navigation, cancellation and failed saves produce no success feedback. Rapid actions are guarded while a transaction is in flight.

The Simulator-only `hns.demo.v1` seed creates three pets, five rounds, three prior complete days and an outstanding BeckonMark, and completes onboarding in the same record before Today can render. Physical devices never seed. ReviewLaunch's scaffold remains; its injectable parser is tested. Presentation reads `ReviewLaunch.screen` once after onboarding. `today` opens the mounted care post, `log` the dated care history, `goals` the handoff guide, `pets` the household, `routines` the ordered care rounds and `settings` local data and support. Extra editor routes are `pet-edit` and `routine-edit`; `history` and `beckon` are aliases. An unknown Simulator key produces a visible diagnostic with the key. These are launch destinations, not tabs.

## Live frame

Today names the job as Morning care. The persistent SpriteView fills the available post viewport and draws the token, the active animals and the selected animal's connection. Native controls sit above this single scene in an uneven 7/5 split. They show the next round, animal names, Hand, completion and the streak rail. The scene grows with the viewport and with the native content rather than occupying a fixed token tile. At accessibility sizes, the columns stack and the page scrolls. All six typography steps scale with Dynamic Type; figures use locale-aware formatting and tabular numerals. Reduce Motion disables numeric travel. Token dragging shows in-flight progress through GestureState and commits only on release over a measured pet target. PostDropTargets shares the native bounds with SpriteKit, using the same coordinate space after rotation and accessibility stacking. A drop over the selected pet records care, a drop over another pet records MissMark, and empty space cancels without a write. There is no directional distance threshold or fallback target. The same durable Hand callback supplies exactly one success haptic for either input.

The visual language uses the existing palette, DIN Alternate headings, 16-point material surfaces, 10-point controls, bold ink borders and tinted material for the live verb. There are no external dependencies or watchOS targets. Native forms validate names and whole-number order, protect unsaved edits and confirm destructive changes. Settings links to the contact page, explains local storage, reruns onboarding and confirms reset. Empty households route first to a pet, then to its care rounds.

## Assets

The seven `hns_` imagesets are empty placeholders for the later assets step. AppIcon remains untouched. No artwork was generated in this layer and no asset prompt was executed. The assigned style is Liquid chrome metallic render; SPEC.md section 13 contains the exact per-asset prompts for that later step. Existing palette and typography tokens are preserved.

## Build and tests

Run from this directory:

```sh
xcodegen generate
xcodebuild build-for-testing -scheme Handsel -destination 'generic/platform=iOS Simulator' -jobs 4 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -derivedDataPath '/Users/belzephyrus/Documents/gambling_factory/.artifacts/genesis/com.handsel.stall/DerivedData' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
xcodebuild -scheme Handsel -destination 'generic/platform=iOS' -jobs 4 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -derivedDataPath '/Users/belzephyrus/Documents/gambling_factory/.artifacts/genesis/com.handsel.stall/DerivedData' SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build
xcrun simctl list devices available
xcodebuild test-without-building -scheme Handsel -destination 'platform=iOS Simulator,id=<UDID>' -jobs 4 -derivedDataPath '/Users/belzephyrus/Documents/gambling_factory/.artifacts/genesis/com.handsel.stall/DerivedData'
```

Signing overrides, warnings-as-errors and DerivedData paths stay on the command line. Tests exercise real aggregate commands, every subset of the day-completion invariant, refused transitions, Miss, Undo, stable routine order, calendar traversal, historical edits, Codable phase replay, disk/defaults relaunch, corrupted data, save failure, cancellation, reset, presentation states, feedback timing, duplicate input, seed and ReviewLaunch parsing. Tests never host a View. Routing tests also require the five sheet review keys to resolve to distinct destinations.
