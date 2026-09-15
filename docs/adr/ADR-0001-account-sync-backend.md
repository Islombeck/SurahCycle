# ADR-0001 — Backend for accounts and progress sync

- **Status:** Accepted for evaluation; blocked on the owner creating a project
  before any real integration (see "Consequences").
- **Date:** 2026-09-15
- **Supersedes:** the "possible Spring Boot + PostgreSQL" placeholder in
  `docs/SERVER_PLAN.md`. Everything else in that document — the invariants, the
  event-envelope model and the conflict thinking — still stands.

## Context

Progress must be able to live under an account, and the owner wants Google and
Yandex sign-in. The app is local-first and must keep working with no account
and no network, so this is an optional layer on top of a working product, not a
dependency of it.

The continuation brief named **Appwrite** as a preliminary preference and
required that the preference be *checked* before being adopted: current Flutter
support for Google **and Yandex** specifically, cost and limits, data export,
hosting region and self-hosting. It also said that if Yandex requires an
unsupported workaround, that must be recorded and a different safe option
chosen.

This ADR is the result of that check. The evidence was gathered on 2026-09-15.

## The decisive fact: Yandex ID is not OpenID Connect

Yandex ID is plain OAuth 2.0 with a Yandex-specific user-info API. It is **not**
an OIDC provider:

- `https://oauth.yandex.ru/.well-known/openid-configuration` returns 404, and so
  does the same path on `login.yandex.ru`; there is no discovery document at the
  consumer OAuth hosts.
- User information comes from `GET https://login.yandex.ru/info`, a Yandex API
  returning `login`, `id`, `client_id`, `psuid` plus permission-gated fields —
  not a standard OIDC `/userinfo`, and the token response has no documented
  `id_token`.
- Yandex Identity Hub, which *can* act as an OIDC provider, is a separate Yandex
  Cloud product for organization SSO. It is not the consumer "log in with
  Yandex" the brief is asking for, and must not be confused with it.

This single fact decides the comparison, because the two obvious alternatives
both reach non-native providers only through OIDC:

- **Supabase** custom providers are *Custom OIDC Providers*: "The discovery
  document, endpoints, and JWKS are resolved automatically from
  `{issuer}/.well-known/openid-configuration`." Yandex publishes none, so it
  does not qualify. (Limit: 3 custom providers per project.)
- **Firebase / Identity Platform** states it plainly: OIDC sign-in requires
  `issuer` + `/.well-known/openid-configuration`, and "if your OIDC provider
  doesn't comply with the OIDC specification for discovery, it won't work with
  Identity Platform." OIDC sign-in also requires the paid Identity Platform
  upgrade and costs $0.015 per MAU after the first 50 users.

With either of those, Yandex sign-in would require **running our own server** to
complete the Yandex OAuth flow, call `login.yandex.ru/info`, and then mint a
Supabase JWT or a Firebase custom token. That is exactly the "unsupported
workaround" the brief told us to reject: it puts a Yandex client secret and a
token-minting key on infrastructure we would have to build, secure and keep
running — for an app whose entire premise is that it works without a server.

**Appwrite lists `yandex` among its built-in OAuth2 providers**, alongside
`google`. No workaround, no bridge server, no custom token minting.

## Options compared

| | Appwrite | Supabase | Firebase |
| --- | --- | --- | --- |
| Google sign-in | native | native | native |
| **Yandex sign-in** | **native provider** | not possible without our own bridge server (needs OIDC discovery) | not possible without our own bridge server (needs OIDC discovery); OIDC also paid |
| Linking Google + Yandex to one account | Identities: an authenticated user starting a second OAuth flow gets that identity linked to the current account | possible, but moot while Yandex is unreachable | possible, but moot while Yandex is unreachable |
| Flutter SDK | official `appwrite` 26.2.0, published ~2026-09-08, verified publisher, Android/iOS/web/desktop | official `supabase_flutter` | official FlutterFire |
| Free tier | 75K MAU, 2GB storage, 5GB bandwidth, 2 projects, 1 database per project | 50K MAU, 500MB DB — but **free projects pause after 1 week of inactivity** (tightened 2026-02-01), ~30s cold start on resume | 50K MAU free on Blaze; Spark capped at 3,000 DAU |
| Paid entry | $25/mo Pro: 200K MAU, 150GB storage, 2TB bandwidth, daily backups (7-day retention) | $25/mo Pro | pay-as-you-go: $0.0055/MAU 50K–100K |
| Region / residency | Frankfurt, NYC, Sydney (+Singapore, Toronto); Frankfurt data stays in the EU. Region choice is a Pro feature | many regions | Google regions; no EU-only guarantee at the auth layer |
| Self-hosting | yes, open source | yes | **no** |
| Export | project export to a self-hosted instance; non-destructive | yes | yes |

The Supabase pause policy deserves a note beyond the table: a personal-scale
app that is used a few times a day would be fine, but a free project that goes
quiet for a week greets the next user with a ~30s cold start. That is a poor fit
for an app opened between prayers.

## Decision

**Use Appwrite** for accounts and progress sync, on Appwrite Cloud, with the
project in the **Frankfurt** region.

It is the only one of the three that supports both required identity providers
natively, and it is the only one that keeps the "no server of our own" property
while doing so. It is also the only one of the three we could later self-host
without rewriting the client, which matters for a religious-practice history we
are treating as sensitive data.

Consequences of the free-tier limits are acceptable for the foreseeable scale
(75K MAU against a single-digit user count), and the Frankfurt region is only
guaranteed on Pro — so if EU residency is required from day one, that is a $25/mo
decision the owner makes, not a technical blocker.

## What this decision does *not* commit us to

- It does not make sync mandatory. The app keeps working with no account and no
  network; that invariant is not negotiable and is enforced by the port design
  in `docs/ACCOUNT_SYNC_ARCHITECTURE.md`.
- It does not put an Appwrite SDK dependency into the app yet. Stage G ships
  ports, an outbox and contract tests with a local fake; the SDK arrives only
  when a real project exists.
- It does not decide the conflict-resolution rules. Those need their own ADR and
  property-based tests before multi-device sync ships, as `docs/SERVER_PLAN.md`
  already says.

## Consequences and open items

1. **A real Appwrite project must be created by the owner.** Per the brief, work
   stops here and asks rather than creating cloud resources unilaterally. What
   is needed is listed in `docs/ACCOUNT_SYNC_ARCHITECTURE.md`.
2. **Client secrets stay out of this repository, the APK, logs and the handoff
   journal — permanently.** In Appwrite's model the OAuth client secret is
   entered in the Appwrite console and stored server-side; the app only needs
   the public project id and endpoint, plus an `appwrite-callback-<PROJECT_ID>`
   intent filter in `AndroidManifest.xml`. Nobody should ever send a client
   secret into this chat or commit it.
3. **Full account erasure needs a server-side path.** Appwrite's client `Account`
   API blocks access but does not delete the user; complete deletion goes
   through the server `Users` API, which requires an API key and therefore an
   Appwrite Function. The "export and full deletion" invariant is not satisfied
   by client code alone, and the Function is part of the work, not an afterthought.
4. **Yandex should be re-checked before the integration is built.** If Yandex ID
   ever publishes an OIDC discovery document this comparison loosens, and if
   Appwrite ever drops its `yandex` provider this decision must be revisited
   immediately, because it is the load-bearing reason for the choice.

## Sources

- Appwrite OAuth providers list, including `yandex` and `google` — <https://appwrite.io/docs/partners/project/oauth>
- Appwrite identities and account linking — <https://appwrite.io/docs/products/auth/identities>
- Appwrite OAuth2 setup (secrets configured in the console) — <https://appwrite.io/docs/products/auth/oauth2>
- Appwrite Flutter SDK, Android callback activity and scheme — <https://github.com/appwrite/sdk-for-flutter>
- `appwrite` package on pub.dev — <https://pub.dev/packages/appwrite>
- Appwrite Cloud pricing — <https://appwrite.io/pricing>
- Appwrite regions and EU residency — <https://appwrite.io/docs/products/network/regions>
- Appwrite GDPR and migration/export — <https://appwrite.io/docs/advanced/security/gdpr>, <https://appwrite.io/docs/advanced/migrations/cloud>
- Supabase custom OIDC providers (discovery document required, 3 per project) — <https://supabase.com/blog/custom-oauth-oidc-providers>
- Supabase social login provider list — <https://supabase.com/docs/guides/auth/social-login>
- Firebase OIDC sign-in requirements (Identity Platform, discovery compliance) — <https://firebase.google.com/docs/auth/android/openid-connect>, <https://docs.cloud.google.com/identity-platform/docs/web/oidc>
- Yandex ID user information endpoint — <https://yandex.com/dev/id/doc/en/user-information>
- Yandex ID overview (OAuth 2.0) — <https://yandex.ru/dev/id/doc/en/>
