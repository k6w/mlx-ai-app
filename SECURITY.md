# Security Policy

The latest release receives security fixes. Do not open a public vulnerability issue; use GitHub private vulnerability reporting and include affected versions, reproduction steps, impact, and mitigations.

MLX AI binds to `127.0.0.1` by design. Privilege escalation, unintended process termination, dependency-installation compromise, and local API exposure are in scope. Intentionally network-exposed modified builds are outside the supported threat model.
