# Reporting security concerns

Please do not publish credentials, account identifiers, raw app-server responses, or exploit details in a public issue.

Use the repository's **Security → Report a vulnerability** option when available. If private reporting is unavailable, request a private contact channel from the maintainer without describing the vulnerability publicly. There is no guaranteed response time; this is a community project.

Useful private reports include the affected version, reproduction steps using synthetic data, expected behavior, actual behavior, and impact. Do not attach real credentials or account data.

The application is intended to keep quota data in memory, use only local read-only account-limit queries, and avoid telemetry. Issues that violate those properties are in scope. Please also report unsafe subprocess handling or accidental exposure of local files.

Only the latest source on the default branch is maintained. No signed or notarized binary release is currently provided.
