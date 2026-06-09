# Browser Workstation

A browser workstation is useful when the client device should be disposable but
the development environment should persist.

The platform combines:

- Coder as the workspace control plane;
- container or VM-backed workspace compute;
- code-server or VS Code Web as the browser IDE;
- Authentik for identity-aware access;
- persistent home-directory storage;
- Git for source and operating knowledge;
- optional AI coding agents inside the workspace.

## Request Path

```text
browser -> public TLS ingress -> Authentik -> Coder -> workspace IDE
```

Coder manages workspace lifecycle and connection metadata. The IDE runs with
the workspace, not on the client. The client needs only a modern browser and an
approved identity.

## Persistence Boundary

Persist the user home directory or selected workspace paths, not the entire
container filesystem. A useful boundary includes:

- source checkouts;
- editor settings and extensions;
- shell configuration;
- tool caches that are expensive to rebuild;
- agent configuration that is intended to follow the workspace.

Do not bake long-lived credentials into workspace images. Inject credentials at
runtime, scope them to the workspace, and make rebuilds routine.

## Workspace Lifecycle

A durable template should define:

1. the base image and architecture;
2. CPU and memory limits;
3. persistent storage mounts;
4. startup scripts and editor applications;
5. network exposure and port-sharing policy;
6. shutdown or idle behavior;
7. the source checkout bootstrap path.

Treat startup scripts as idempotent. A workspace may restart many times while
its persistent data remains.

## Identity Boundaries

There are two separate identity questions:

1. Who may enter Coder and start a workspace?
2. What may code inside the workspace access?

Authentik or another OIDC provider can answer the first. Repository deploy keys,
short-lived credentials, workload identity, or a secrets manager should answer
the second. Do not make browser login cookies double as infrastructure
credentials.

## Operational Checks

Validate the complete path after upgrades:

- browser login and logout;
- workspace start, stop, and rebuild;
- persistent files after workspace recreation;
- editor extension loading;
- Git fetch and push with the intended identity;
- terminal and WebSocket stability through the proxy;
- client behavior from a machine with no local developer tooling.

Coder supports desktop VS Code, browser VS Code through code-server, SSH, web
terminals, and additional IDEs. Choose the smallest exposed surface that covers
the intended workflow.

## References

- [Coder workspace access](https://coder.com/docs/user-guides/workspace-access)
- [Coder and VS Code](https://coder.com/docs/user-guides/workspace-access/vscode)
