<!-- gf-brief source=5436ee2d3a22b8f7c1651cbb554548ca622718945f67d704bab8c2dfd0b18b52 written=2026-10-28T17:50:59+03:00 -->
# Fishnote

## What it is

Fishnote records daily pet-care routines for a household with one or more animals. Users name their pets, arrange each pet’s care rounds, and use a token to record completed care, review daily history, and track consecutive complete days.

## Launch and onboarding

On a normal first launch on a device, a loading view can appear briefly before the introduction. There is no login or permission prompt.

The introduction has three illustrated pages. Each shows “Morning care, together.” and a page counter: “1 of 3”, “2 of 3”, or “3 of 3”.

1. “A round for every pet.”
   
   “Give each animal a name and a daily care round. Keep morning care together in one place.”
   
   “Continue” advances to the second page.

2. “Beckon. Then hand.”
   
   “Choose a pet with Beckon. Hand it the token to log the next round. A handoff to another pet never counts as care.”
   
   “Continue” advances to the third page.

3. “A small record of care.”
   
   “Finish every care round due to complete the day. Your household and its history stay on this device.”
   
   “Start caring” completes the introduction and opens “Today”.

“Skip” is available on every page and also completes the introduction. While completion is being saved, the main button reads “Saving…” and both buttons are disabled. If saving fails, the page stays open with “The introduction could not be saved. Please try again.”

On a new device installation, “Today” initially shows “Make room for care.”, “Add a pet and a care round to start your mornings.”, and “Add a pet”. After saving an active pet, it shows “Set the morning round.”, “Give each animal a care round, then return here to log it.”, and “Add care round”.

Later launches return to “Today” with saved household information and the current day’s progress. Simulator starter content behaves differently, as described below.

## Screens

There is no tab bar. “Today” is the main screen; the other destinations open above it. Main destination screens have “Close”, which dismisses the current destination.

Dynamic names and counts below describe changing content; pet and care-round names appear exactly as entered.

### “Today”

The screen shows the current date, “Morning care”, and “Log each animal's morning care round.” When all due rounds are logged, the message becomes “Every round is logged. Your day is complete.”

Navigation controls:

- “Pets” opens “Pets”.
- The checklist icon, with accessibility label “Routines”, opens “Routines”.
- The gear icon, with accessibility label “Settings”, opens “Settings”.
- The bottom summary shows the streak count, “Complete days in a row”, and “Open the care log”. Tapping it opens “Care log”. At larger accessibility text sizes, its label is “Care log”.

The care board contains illustrated animals, a draggable token, the selected pet’s name and next care-round name, and progress.

Board status is “Choose a pet”, “Ready for care”, or “Day complete”. Before selection, the token area says “Choose an animal” and “Your next round starts with a name.” After completion, it says “All cared for”; the same secondary sentence remains.

Controls and indicators:

- A pet with unfinished care initially shows its name and “Beckon”. Tapping selects that pet without recording care.
- The selected pet shows “Hand”. Tapping its card records its next unfinished round.
- Other pet cards show “Give token” while a pet is selected. Tapping one records a miss without completing care or changing the selection.
- A pet with no remaining rounds shows “Care complete”.
- “Hand” records the next unfinished round for the selected pet. While saving, it reads “Saving care…”.
- The instruction is “Drag the token to an animal, or use the button.” Dragging the token to the selected pet also records its next unfinished round. The drag indicator has accessibility label “Handoff progress”.
- Progress shows the completed count, “of”, the total due count, and “Rounds logged”.
- “Undo” appears when a current care round can be undone. It reopens the most recent eligible round and selects its pet again.
- The question-mark button, with accessibility label “How care works”, opens the guide.

### “Pets”

The summary says “Your household” and displays counts in the form “3 pets · 5 daily routines”.

- “Add a pet” opens “Add a pet”.
- Each pet card shows its name, “Edit”, and either a count such as “2 daily routines” or “Care paused”.
- Cards list active routine names separated by “ · ”, or “No routines yet”.
- Tapping a card opens “Edit pet”.
- With no pets, the screen says “Add your first pet, then give it a daily care round.”

### “Add a pet” and “Edit pet”

The form contains:

- “Pet name”, with the text field “Name”.
- “Include in daily care”, a toggle enabled by default for a new pet.
- “Paused pets stay in your household and keep their past care records.”
- “Save pet”, which saves and returns to the preceding screen. During saving it reads “Saving pet…”.
- “Close”, which dismisses an unchanged form or asks about discarding edits.

An empty or whitespace-only name shows “Give this pet a name to save.” and disables saving.

Closing a changed form presents “Discard pet changes?” with:

- “Discard changes”: leaves without saving.
- “Keep editing”: returns to the form.

An existing pet also has “Remove ” followed by its name. Tapping it presents “Remove ” followed by the pet’s name and “?”, with the message “Their routines will leave today's care. Past care records are kept.”

- “Remove pet” removes the pet and its routines.
- “Cancel” keeps them.

Save errors appear under “Could not save”, with “Retry”:

- “Your pet was not saved. Check the name and retry.”
- “The pet could not be removed. Try again.”

### “Routines”

The summary says “Daily care order” and “Choose a pet, then tap Edit. Rounds run from top to bottom.”

- “Choose a pet” heads buttons bearing the household’s pet names. Tapping a name displays that pet’s rounds and marks the selection with a checkmark.
- The selected pet’s summary shows its name and a count such as “1 daily round” or “2 daily rounds”, or “Care paused”.
- Each numbered round shows its name, “Every day” or “Paused”, and “Edit”. Tapping the row opens “Edit care round”.
- “Add care round” opens a new round with the displayed pet selected.
- A pet with no rounds shows “No rounds yet. Add a care round below.”
- With no pets, the screen says “Add your first pet to set up daily care rounds.” The bottom control becomes “Add a pet” and opens the pet form.

Switching pets returns the routine list to the top.

### “Add care round” and “Edit care round”

Under “Care round”, the form contains:

- “Care round name”: editable text.
- “Pet”: a chooser containing “Choose a pet” and the household’s pet names.
- “Order”: a whole-number field.
- “Include every day”: a toggle enabled by default for a new round.

The explanation is “The lowest order goes first. The next unfinished round is recorded for the animal you choose.”

A new round normally starts with an available pet selected and an order one greater than the largest existing order.

Controls:

- “Save care round” saves and returns to the preceding screen. While saving it reads “Saving care round…”.
- “Done” dismisses the keyboard.
- “Close” dismisses an unchanged form or asks about discarding changes.
- Existing rounds also have “Remove care round”.

Incomplete fields show “Enter a name, choose a pet and set a whole-number order.”

Closing a changed form presents “Discard care round changes?” with “Discard changes” and “Keep editing”.

Removing a round presents “Remove ” followed by its name and “?”, with “This removes the round from daily care. Existing history is kept.”

- “Remove care round” confirms removal.
- “Cancel” keeps it.

Errors appear under “Could not save”, with “Retry”:

- “The care round was not saved. Check its pet and order, then retry.”
- “The care round was not removed. Your records are unchanged. Please try again.”

### “Care log”

The top panel shows:

- “Today's care”.
- The completed count, “of”, the total due count, and “rounds logged”.
- A progress bar with accessibility label “Today's completed care”.
- A streak statement such as “3 complete days in a row”.
- “Continue today's care”, which dismisses the log and returns to “Today”. When today is complete, this becomes “View today's care”.

Dated entries appear newest first, grouped by pet. Day status is “Complete”, “In progress”, or “Archived”. Each care round has a status of “Logged”, “Due”, or “Archived”; rounds no longer included in daily care also show “Archived care”.

The empty-history message is “Your logged rounds will appear here, grouped by day and pet.” A dated entry can already exist before the first round is logged because opening a day creates its care list.

The log has no controls for editing past days.

### “How care works”

The guide starts with “Log a care round” and “The token records one finished care round for the pet you choose.”

It contains three numbered instructions:

1. “Beckon”: “Choose a pet with care still due. Its name appears beside the token.”
2. “Hand”: “Tap Hand or drag the token to that pet. Its next unfinished care round is saved on this device.”
3. “Finish”: “Log every care round to complete the day. Undo restores the last round and selects that pet again.”

The final explanation is “Giving the token to another pet records a miss, not care. The selected pet keeps its place.”

“Return to care” dismisses the destination and returns to “Today”.

### “Settings”

“Your care summary” shows the streak count and “complete days in a row”. “Open care log” opens “Care log”.

Under “Help with Fishnote”:

- “How care works”, with “Choose a pet, hand the token, log care.”, opens the guide.
- “Contact Fishnote” opens the external contact page.
- “Read the introduction” dismisses settings and restarts the three introduction pages without deleting household data.

The data section contains:

- “Saved on this device”.
- “Pets and care rounds stay on this device. No account or network is required.”
- “Reset all data”.
- “Removes this household's pets, routines and care history.”

“Reset all data” presents “Reset all pets and care rounds?” and “This removes every pet, care round and care log from this device.”

- “Reset all data” confirms deletion, dismisses settings, and returns to the introduction with an empty household.
- “Cancel” leaves the data intact.

While resetting, the control reads “Resetting…” and is disabled.

## Features

- “Pets”: create, rename, pause, reactivate, and remove household pets.
- “Routines”: create, name, assign, order, pause, reactivate, and remove daily care rounds.
- “Beckon”: select a pet with care still due.
- “Hand”: record one completed round by button, pet-card tap, or token drag.
- “Undo”: reopen the latest eligible round from today.
- “Day complete”: automatic completion after every currently due round is logged.
- “Care log”: dated care records grouped by pet, including retained “Archived care”.
- “Complete days in a row”: consecutive complete-day tracking.
- “How care works” and “Read the introduction”: in-app instructions.
- “Saved on this device”: offline household records and progress.
- “Reset all data”: remove the household and its history.
- Accessibility text sizing, spoken control descriptions, reduced-motion support, and success haptics.

## Behaviours that can look like bugs

- **Care takes two actions.** “Beckon” only selects a pet. “Hand” records care. After every successful round, selection clears deliberately; select a pet again for the next round, even when it is the same pet.
- **Another pet does not replace the selection.** “Give token” records a miss. The notice is “That animal is still waiting. Give the token to the selected animal to record care.” Finish the selected pet’s next round before choosing another.
- **A missed drag changes no care progress.** Dropping outside an animal shows “No animal received the token. Your care record is unchanged.” Drag onto the selected animal or use “Hand”.
- **“Hand” is disabled until a pet with due care is selected**, during saving, and after the day is complete. Pet cards are disabled during saving and after completion; without a selection, pets with no due care cannot be selected.
- **Completion is automatic.** There is no separate finish button. “Undo” reopens a completed day. It only applies to today’s latest logged round still included in daily care; archived rounds cannot be undone.
- **A household without active care shows setup prompts.** Use “Add a pet” and “Add care round”, or reactivate paused pets and rounds through “Pets” and “Routines”.
- **Saving requires valid input.** “Save pet” needs a nonblank name. “Save care round” needs a nonblank name, a pet, and a whole-number order of zero or greater. Non-digit order input is rejected.
- **Changed forms resist dismissal.** Swipe dismissal is blocked while there are unsaved changes or saving is underway. Use “Close”, then “Discard changes” or “Keep editing”. Closing and removal controls are disabled during saving.
- **A round logged today cannot be reassigned to another pet.** The app reports “This round already has a log today. Add a new care round for the other pet.” Keep its existing assignment and create a separate round.
- **Editing care changes today’s totals.** Adding or reactivating a round can reopen a complete day. Pausing or removing pets or rounds removes their current obligations. Already logged care remains in the log as archived care; earlier days retain their recorded names and rounds.
- **Daily progress starts fresh on a new local calendar day.** Previous history remains. The app checks for a new day when returning to the foreground and periodically while open.
- **An empty day is not a complete day.** Days without recorded completion break the streak. While today remains unfinished, the streak can still show consecutive complete days ending yesterday.
- **“Read the introduction” intentionally loops back to onboarding.** “Skip” or “Start caring” returns to the saved household.
- **“Reset all data” clears progress and restarts onboarding.** It does not restore sample pets on a normal device.

Loading and saving failures use “Care could not be loaded.” on “Today”, or “Your changes could not be loaded or saved.” on other main screens. “Retry” reloads saved information.

Recovery messages can be:

- “The household was recovered from its backup. Review your latest round, then save again.”
- “The household was recovered from its local copy. Review your latest round, then save again.”
- “The household could not be read. The damaged data was kept. Retry storage or reset to start again.”
- “The household record is invalid. Retry loading your saved data.”
- “The household could not be saved or opened.” followed by the specific failure reason and “Retry before leaving.”

Additional refusal messages explain the next action:

- “Beckon a pet before handing the care token.”
- “This day is complete. Undo the latest logged round to reopen it.”
- “Hand to the pet already beckoned before beckoning another.”
- “Choose an active pet from Pets.”
- “This pet has no rounds left. Beckon a pet that still owes care.”
- “Add a pet and a care round to begin.”
- “There is no current care round to undo. Archived care stays in the log.”
- “Enter a name before saving.”
- “Use a care-round order of zero or greater.”
- “Choose a care round from Routines.”
- “Choose a valid calendar day.”

## Starter content and resume

Normal device installation: **None**. Users create their own pets and care rounds.

A fresh simulator installation starts with:

- “Mabel”: “Breakfast”, then “Morning walk”.
- “Otis”: “Fresh water”, then “Breakfast”.
- “Pip”: “Clean bedding”.

The simulator has three prior complete days, skips the initial introduction, and starts today with “Mabel” selected and no rounds yet logged today. There is no user-facing sample-content switch.

Saved pets, routines, current-day selection, completed rounds, and history survive relaunch. An unfinished day can be resumed that day. A new day starts its own care list; unfinished earlier days remain visible but cannot be completed retrospectively. Unsubmitted editor text and the current introduction page are not saved for relaunch.

## Permissions

None. The app asks for no system permissions and supplies no permission usage-description strings.

## Absent

Genuinely absent:

- Login or accounts.
- In-app purchase.
- Ads.
- Analytics.
- Account deletion flow.
- App Tracking Transparency prompt.

User-created content is present as private pet names, care-round names, and care records. Public posting, sharing feeds, messaging, and other social user-generated content are absent.

## Data and support

Household data and care history stay on this device. Core use requires no network connection. There is no in-app cloud synchronization or export control.

“Settings” contains “Contact Fishnote”, which opens an external contact page. “Reset all data” deletes the local household and its care history.

## Scanning and health

None. There is no barcode or QR-code scanning, medical advice, health assessment, or product-health information. Care-round names are user-entered organizational labels. There are no health citations.

## Platform

- Display name: “Fishnote”.
- iPhone and iPad.
- Minimum iOS version: iOS 17.0.
- iPhone orientations: portrait and both landscape directions.
- iPad orientations: portrait, upside-down portrait, and both landscape directions.
- Requires full-screen presentation on iPad.
- Uses a light appearance.
- Interface copy is English; no additional translations are supplied.
- Dates and formatted numbers follow device regional settings. Daily boundaries and streak calculations use the device’s current calendar and local time.
- No region-based content changes or restrictions are present.

## Category

Lifestyle.
