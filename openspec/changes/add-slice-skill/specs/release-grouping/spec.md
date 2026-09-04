## ADDED Requirements

### Requirement: A release record names the changes in the slice

The skill SHALL write `ralph/releases/<release>.md` recording the release name, the date, each cell as `<activity>-<depth>`, its change name, and its status.

#### Scenario: Record is written on confirmation

- **WHEN** the user confirms a slice
- **THEN** `ralph/releases/<release>.md` exists and lists every change in the slice with status `pending`

#### Scenario: Release name is chosen by the user

- **WHEN** the skill materialises a slice
- **THEN** it asks for the release name and uses it for both the file and the record

#### Scenario: Records accumulate

- **WHEN** a second slice is materialised later
- **THEN** the earlier release record is left unchanged and a new one is added

### Requirement: The skill reports release status

`/ralph-loop:slice --status` SHALL read the release records and report, for each change, whether it is pending, in progress, or archived. It SHALL name the release as shippable only when every change in it is archived.

#### Scenario: Release is part done

- **WHEN** some changes in a release are archived and others are not
- **THEN** the report shows each change's status and does not call the release shippable

#### Scenario: Release is complete

- **WHEN** every change in a release is archived
- **THEN** the report states the release is complete and ready to tag

#### Scenario: No releases yet

- **WHEN** `ralph/releases/` is absent or empty
- **THEN** the report says no release has been sliced yet

### Requirement: Release records are never archived

`ralph/releases/` SHALL be excluded from spec archiving, in the same way `ralph/AUDIENCE_JTBD.md` is, because the records describe history that spans releases.

#### Scenario: Cleanup leaves releases alone

- **WHEN** `/ralph-loop:cleanup` runs
- **THEN** no file under `ralph/releases/` is moved or deleted
