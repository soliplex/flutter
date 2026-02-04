# M3: 02 - Authentication Flow

## Files (19)

Pass these ABSOLUTE paths to Gemini `read_files` (batch into 2 calls):

**Batch 1 (14 files):**
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/auth_flow.dart
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/auth_flow_native.dart
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/auth_flow_web.dart
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/auth_notifier.dart
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/auth_provider.dart
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/auth_state.dart
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/auth_storage.dart
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/auth_storage_native.dart
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/auth_storage_web.dart
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/callback_params.dart
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/oidc_issuer.dart
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/web_auth_callback.dart
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/web_auth_callback_native.dart
- /Users/runyaga/dev/soliplex-flutter/lib/core/auth/web_auth_callback_web.dart

**Batch 2 (5 files):**
- /Users/runyaga/dev/soliplex-flutter/lib/features/auth/auth_callback_screen.dart
- /Users/runyaga/dev/soliplex-flutter/lib/features/login/login_screen.dart
- /Users/runyaga/dev/soliplex-flutter/packages/soliplex_client/lib/src/auth/auth.dart
- /Users/runyaga/dev/soliplex-flutter/packages/soliplex_client/lib/src/auth/oidc_discovery.dart
- /Users/runyaga/dev/soliplex-flutter/packages/soliplex_client/lib/src/auth/token_refresh_service.dart

## Tasks

- [x] Claude: Collect the 19 absolute file paths above
- [x] Gemini (`gemini-3-pro-preview`): `read_files` with THIS MILESTONE .md + Batch 1 (14 source files)
  - Prompt: See PLAN.md "Standard Gemini Prompt"
- [x] Gemini (`gemini-3-pro-preview`): `read_files` with THIS MILESTONE .md + Batch 2 (5 source files)
  - Prompt: See PLAN.md "Standard Gemini Prompt"
- [x] Claude: Draft `components/02-authentication.md` from Gemini's analysis
- [x] Claude: Move any BACKLOG items to `BACKLOG.md`
- [x] Codex (`gpt-5.2`, 10min timeout): Review draft for completeness
  - Fallback: Gemini review if timeout
- [x] Claude: Mark M3 complete in TASK_LIST.md

## Output

`components/02-authentication.md`
