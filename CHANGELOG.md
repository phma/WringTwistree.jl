# Changelog for `WringTwistree`

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to the [Semantic Versioning](https://semver.org/).

## 1.1.0 - 2025-01-07

### Added

- Documentation of exported functions and structs
- Method for setting parallel/serial thresholds to predetermined values

### Fixed

- Bug that threw an error with a one-byte key

### Removed

- Dependencies ProfileView, Revise, and Debugger

### Deprecated

- Exported functions that shouldn't have been. They will be unexported, not deleted.

## 1.0.0 - 2024-05-31

### Added

- Non-exported functions for cryptanalysis
- Exported structs Wring and Twistree
- Keeping users from creating invalid Wring or Twistree
- 15-byte test vectors

### Changed

- Increased number of rounds in Wring, because cryptanalysis showed it was not sufficient for security of large messages

## 0.1.0 - 2024-01-14

### Added

- Keying, common to Wring and Twistree
- Whole-message cipher Wring
- Keyed hash algorithm Twistree
- Test vectors for both algorithms
- Parallel option for large messages
