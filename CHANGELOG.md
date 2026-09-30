# Change Log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [2.0.0.1] - 2026-09-30

### Fixed

• Set the summaryVisibility of the password field to "Hide element" instead of "Show". This will prevent the generated password to be visible in the logging.

## [2.0.0.0] - 2026-02-19

### Added
- Added GitHub Actions workflow for automated release creation (`Create Release` workflow)
- Added GitHub Actions workflow to verify CHANGELOG.md updates on pull requests (`Verify CHANGELOG Updated` workflow)
- Added password generation data source that creates random passwords meeting security requirements
- Added support for ObjectGuid as user identifier in addition to UserPrincipalName for more reliable account management
- Added comprehensive error handling with detailed error messages and line number information
- Added support for separating multiple OUs with semicolon (`;`) delimiter instead of JSON array format

### Changed
- **BREAKING**: Refactored AD user search data source old data source `AD-user-generate-table-wildcard-reset-password-ict` to `AD-Get-All-Users` with improved filtering and property selection
- **BREAKING**: Replaced manual password entry with auto-generated password data source
- **BREAKING**: Changed ADusersSearchOU variable format from JSON array to semicolon-delimited string
  - Old format: `[{ "OU": "OU=Users,OU=enyoi,DC=enyoi,DC=local"},{ "OU": "OU=UsersLite,OU=enyoi,DC=enyoi,DC=local"}]`
  - New format: `OU=Users,OU=enyoi,DC=enyoi,DC=local;OU=UsersLite,OU=enyoi,DC=enyoi,DC=local`
- Updated form schema with improved grid columns and better user experience
- Refactored task script to use ObjectGuid for account identification instead of relying solely on UserPrincipalName
- Improved task error handling with separate try-catch blocks for each operation (reset, change password at logon, unlock)
- Updated password validation regex pattern with detailed validation failure messages
- Enhanced delegated form script to handle empty access groups gracefully
- Improved code formatting and consistency across all PowerShell scripts
- Updated README with comprehensive documentation including requirements, remarks, and cmdlet references

### Removed
- Removed old data source `AD-user-generate-table-attributes-basic-reset-password` (no longer showing basic attributes in a seperate grid)

### Deprecated
- Deprecated support for JSON array format in ADusersSearchOU variable (use semicolon-delimited string instead)

## [1.0.1] - 2021-11-03

### Added
- Added version number to script

### Changed
- Updated all-in-one script

## [1.0.0] - 2020-09-01

### Added
- Initial release of HelloID-Conn-SA-Full-AD-AccountPasswordResetUnlock
- Basic AD account password reset functionality
- AD account unlock functionality
- Form-based user selection
- Password and unlock options as toggleable switches
