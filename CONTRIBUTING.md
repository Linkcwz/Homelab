# Contributing

Contributions should improve reproducibility without exposing a live
environment.

## Useful Contributions

- tested runbooks with clear prerequisites and rollback steps;
- parameterized scripts that do not depend on one operator's paths;
- architecture diagrams that show dependencies and trust boundaries;
- failure reports that include detection, cause, repair, and validation;
- example configurations using reserved example domains and addresses;
- validation tools that fail clearly and do not modify the system under test.

## Do Not Include

- credentials, private keys, session cookies, or encrypted credential stores;
- personal records or account identifiers;
- live internal or public addresses tied to an operating environment;
- database exports, application state, logs, archives, or backup payloads;
- local profile paths or machine-specific access instructions.

## Validation

Run the repository checks before proposing a change:

```powershell
./scripts/Test-PublicRepository.ps1 .
```

Examples must use actual syntax and named products where practical. Replace
only the values that identify or grant access to a specific deployment.
