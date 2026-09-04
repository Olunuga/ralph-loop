## ADDED Requirements

### Requirement: Assets live beside the intent they belong to

A design reference SHALL live in an `assets/` directory inside the intent it belongs to. For a legacy spec that is `ralph/specs/<name>/assets/`, where `ralph/specs/<name>/` also holds `spec.md`. For an OpenSpec change that is `openspec/changes/<name>/assets/`.

#### Scenario: Legacy spec with a reference

- **WHEN** a spec named `<name>` has a design reference
- **THEN** the spec is `ralph/specs/<name>/spec.md` and the image is under `ralph/specs/<name>/assets/`

#### Scenario: OpenSpec change with a reference

- **WHEN** an OpenSpec change named `<name>` has a design reference
- **THEN** the image is under `openspec/changes/<name>/assets/`

#### Scenario: Existing single-file specs keep working

- **WHEN** a spec exists as `ralph/specs/<name>.md` with no directory
- **THEN** every command that reads specs treats it exactly as it does today

### Requirement: Archiving moves assets with the spec

`bin/cleanup_specs.sh` SHALL move a spec directory to `ralph/specs/done/` as a unit, so its `assets/` are archived with it. It SHALL continue to move a single-file spec.

#### Scenario: Directory spec is archived whole

- **WHEN** cleanup archives `ralph/specs/<name>/` containing `spec.md` and `assets/`
- **THEN** `ralph/specs/done/<name>/` contains both, and no asset is left behind

#### Scenario: Single-file spec is archived

- **WHEN** cleanup archives `ralph/specs/<name>.md`
- **THEN** it moves to `ralph/specs/done/<name>.md` as it does today

#### Scenario: Spec is missing

- **WHEN** the named spec is neither a file nor a directory
- **THEN** cleanup reports it as not found and continues with the rest
