# Identity-Aware Ingress

The ingress path separates transport, authentication, and application
authorization:

```text
client -> Caddy -> Authentik proxy outpost -> application
```

Caddy owns TLS, request routing, and upstream transport. Authentik decides
whether the request is authenticated and allowed. The application still owns
its internal roles unless it deliberately consumes identity headers.

## Authentik Setup

For one protected hostname:

1. Create an Authentik application and a **Proxy Provider**.
2. Select **Forward auth (single application)**.
3. Set the external host to the application's public URL.
4. Bind a group or policy. An application with no bindings is normally
   available to every Authentik user.
5. Add the provider to an embedded or standalone proxy outpost.

Domain-level forward auth is convenient for many applications, but it reduces
per-application policy separation. Prefer single-application mode when
different services have different audiences.

## Caddy Pattern

The included [Caddyfile](../examples/Caddyfile) follows Authentik's documented
standalone Caddy pattern:

```caddyfile
app.example.com {
    route {
        reverse_proxy /outpost.goauthentik.io/* http://authentik-outpost:9000

        forward_auth http://authentik-outpost:9000 {
            uri /outpost.goauthentik.io/auth/caddy
            copy_headers X-Authentik-Username X-Authentik-Groups X-Authentik-Email
            trusted_proxies private_ranges
        }

        reverse_proxy http://app:8080
    }
}
```

The `route` block is intentional. Caddy normally sorts directives into its
standard execution order; `route` preserves the order written inside the
block. The Authentik callback path must reach the outpost, authorization must
happen next, and the application proxy must run only after authorization.

## Header Boundary

Only trust identity headers that arrive from the proxy path. Direct access to
the application should be blocked at the network layer or the application
should discard client-supplied identity headers.

Useful Authentik response headers include:

- `X-Authentik-Username`
- `X-Authentik-Groups`
- `X-Authentik-Entitlements`
- `X-Authentik-Email`
- `X-Authentik-Name`
- `X-Authentik-Uid`

Copy only the headers the upstream needs.

## Validation

Validate the Caddy syntax before reload:

```sh
caddy validate --config ./examples/Caddyfile --adapter caddyfile
```

Then verify the full browser path:

1. An unauthenticated request redirects to Authentik.
2. An allowed user reaches the application.
3. A denied user receives the intended denial response.
4. The callback path does not loop.
5. WebSocket or long-lived application connections remain stable.
6. Direct access to the application cannot forge trusted headers.

Service health alone is insufficient. The browser path includes DNS, TLS,
Caddy, the outpost, Authentik policy, cookies, and the application upstream.

## References

- [Authentik Caddy integration](https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_caddy)
- [Authentik forward auth](https://docs.goauthentik.io/docs/add-secure-apps/providers/proxy/forward_auth)
- [Caddy `forward_auth`](https://caddyserver.com/docs/caddyfile/directives/forward_auth)
- [Caddy `route`](https://caddyserver.com/docs/caddyfile/directives/route)
