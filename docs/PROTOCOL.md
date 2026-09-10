# OpenAI connection record

## Reference sources

Pi Coding Agent is the design reference.
The implementation follows Pi revision `6160683a4a8012f0d1cd30c145df18b4ca6f5176` for protocol details:

- [OAuth source](https://github.com/earendil-works/pi/blob/6160683a4a8012f0d1cd30c145df18b4ca6f5176/packages/ai/src/auth/oauth/openai-codex.ts).
- [Codex response source](https://github.com/earendil-works/pi/blob/6160683a4a8012f0d1cd30c145df18b4ca6f5176/packages/ai/src/api/openai-codex-responses.ts).

The catalog route follows the [official Codex model endpoint](https://github.com/openai/codex/blob/main/codex-rs/codex-api/src/endpoint/models.rs).
These sources describe the account protocol.
Native Pharo integration passed on 2026-09-09 with model `gpt-5.6-luna`.
The check covered browser login, Keychain recovery in a new process, and a complete `SMALLGPTALK_OK` response.
The release example also passed: method repair, SUnit, conversation continuation, token renewal, and sign-out.
See [the validation record](../PLAN.md) for the exact image and VM versions.

## Account login

OAuth exchanges a browser authorization code for account credentials.
PKCE binds that exchange to the login operation through a secret verifier and a SHA-256 challenge.
SmallGPTalk also checks a secure random state value on the local callback.

| Setting | Value |
| --- | --- |
| Authorization endpoint | `https://auth.openai.com/oauth/authorize` |
| Token endpoint | `https://auth.openai.com/oauth/token` |
| Client identifier | `app_EMoamEEZ73f0CkXaXp7hrann` |
| Redirect URI | `http://localhost:1455/auth/callback` |
| Callback listener | `127.0.0.1:1455` |
| Scope | `openid profile email offline_access` |
| Challenge method | `S256` |
| Originator | `smallgptalk` |

The authorization request also sets `id_token_add_organizations=true` and `codex_cli_simplified_flow=true`.
The caller opens the returned URL. Zinc receives the callback and exchanges the code.
A wrong state does not exchange a code. A refused login or timeout reports a failure.
Account objects with the same native Keychain service and account share login and renewal coordination in the image.
Only one login operation can be active for that credential record.
The callback port must be available.

The account reads credentials from its store for each use.
It renews tokens within 60 seconds of expiry and updates the store after renewal.
The default store uses the native Security.framework functions `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, and `SecItemDelete`.
Blocking native calls use threaded FFI.
See Apple's [Keychain guidance](https://developer.apple.com/forums/thread/724023).

## Model requests

The response endpoint is `https://chatgpt.com/backend-api/codex/responses`.
The catalog endpoint is `https://chatgpt.com/backend-api/codex/models` with a `client_version` query value.
The default Codex catalog compatibility version is `0.153.4`; set another value with `provider clientVersion:`.
This value describes the catalog protocol. The SmallGPTalk product version remains `0.1`.
`provider models` returns the identifiers listed for the account. It does not use a fixed model list.
Request headers include the bearer access token and `chatgpt-account-id`.
SmallGPTalk disables HTTP logging and automatic request retries.
`SmallGPTalkOpenAIHTTPClient` requires HTTPS and checks the certificate chain and host name before it sends a request.
Native TLS checks rejected expired, self-signed, and wrong-host certificates.
HTTP proxies are not supported.

The session must specify a model identifier. SmallGPTalk does not select a replacement model after an access error.
Requests set `store=false` and `stream=true`.
They include `reasoning.encrypted_content` so that later turns can preserve required provider items.
The provider keeps complete assistant output items in the conversation.

The HTTP event stream can divide text and function arguments into fragments.
The client accepts `text/event-stream` and `application/octet-stream`, as returned by the live service.
The parser collects complete items from `response.output_item.done` and waits for the terminal completion event.
The terminal response can have an empty output array; the completed items supply its content.
The parser validates item order, completion, and tool arguments before returning an assistant message.
The loop executes tools only after that complete response is committed.
Tool outputs keep their function call identifiers.
A broken stream fails the response and does not execute partial calls.

An HTTP 401 permits one token renewal and one new request.
A second authentication failure ends the request.
Other HTTP failures, rate limits, timeouts, and broken streams return errors without automatic retries.
Completed tools are not replayed by request recovery.

## Reasoning effort

The provider sends `reasoning.effort`, with `medium` as its default.
The chat reads `supported_reasoning_levels` from the account model catalog.
Each entry supplies an `effort` value. The chat offers those values only.
The chat selects `gpt-5.6-luna` when that model is in the catalog.
A live request with this model and medium effort executed evaluate successfully.
