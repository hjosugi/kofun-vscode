# Kofun for VS Code

The VS Code client for the [Kofun](https://github.com/hjosugi/kofun) language.

This repository owns the editor client only. The language, the toolchain and
the language server live in `hjosugi/kofun`, and the dependency runs one way:
this repository pins that one as a submodule and copies the server out of it at
build time. Nothing here is on kofun's side of the line, so a change to the
extension cannot break a language gate, and the language repository does not
carry a VS Code publishing pipeline it never runs.

The server is **not committed here**, on purpose. `tests/lsp/check.sh` in kofun
requires the server's semantic bundle to equal that repository's
`tooling/typed-sidecar/{from-stage2,codec}.mjs` byte for byte, and only a
checkout that owns those files can prove it. Vendoring a built copy here and
calling it verified would be a claim this repository cannot make; instead
`scripts/vendor-server.sh` rebuilds it from the pinned checkout, so the bytes
come from the same source the upstream gate checks.

This extension provides `.kofun` language registration, comments, brackets,
indentation, TextMate highlighting, and snippets, plus a bundled stdio language
server offering inline diagnostics, go-to-definition, hover types, completion,
a document outline, find-all-references, occurrence highlighting, and inlay
hints. The server starts when a Kofun document opens. Everything it reports for
the covered Stage 2 subset consumes one validated in-memory typed sidecar;
sources outside the bounded producer profile use a visibly labelled syntactic
fallback.

## Installing

The extension publishes as **`hjosugi.kofun`**:

```sh
code --install-extension hjosugi.kofun
```

Or search for *Kofun* in the Extensions view. The marketplace page is
<https://marketplace.visualstudio.com/items?itemName=hjosugi.kofun>.

Nothing is published there yet — the identity is decided and pinned, and the
first release is what will make that URL resolve. Until then, build a VSIX with
`scripts/package-extension.sh` and install it with
`code --install-extension dist/kofun-<target>-v<version>.vsix`.

## What the editor shows

- **Inlay hints** put the callee's parameter name — and its `read`/`edit`/`take`
  mode — before each call argument, so `process(data)` reads as
  `process(take data:)` without opening the callee. The mode is declared in the
  signature but its consequence lands on the caller, which is why it is shown
  here. A `let` without a written type shows the inferred one; a type the
  server cannot determine is left blank rather than guessed at. Each of the
  three is switchable under `kofun.inlayHints`.
- **Completion** offers the names visible at the cursor under the same
  visibility and shadowing rules go-to-definition resolves by, so the two never
  disagree. Items state whether their type came from the validated sidecar or
  the syntactic fallback.
- **Outline and breadcrumbs** nest each function's parameters and locals under
  it.
- **References and highlights** resolve through the same rule, so a shadowed
  name is not swept up with the one shadowing it.
- **Signature help** tracks which argument the caret is in, across nested
  calls, and shows nothing outside a call rather than the last signature it
  produced.
- **Folding** covers block bodies and runs of comment lines; **selection
  ranges** expand from the token through each enclosing block.
- **Semantic tokens** colour by what a name resolved to, not by its spelling,
  so a parameter and a local sharing a name are drawn differently. An
  unresolved name is left to TextMate rather than coloured as a guess.
- **Rename** covers locals and parameters. Renaming a function or a type is
  refused: they can be named from a file this server never reads, so the rename
  would edit some uses and leave others behind.
- **Tasks** run `kofun check`, `build`, and `test` on the active file.

## What is deliberately absent

There is no code-action provider. No diagnostic in `tests/diagnostics/registry.tsv`
carries a remedy today, so the capability would advertise a quick-fix list the
server can never fill; it belongs here once one does. Completion advertises no
trigger characters for the same reason — member and field completion is not
implemented, so `.` must not promise a list that cannot be produced.

The tasks contribute no problem matcher. The CLI reports byte offsets rather
than line and column, so a matcher would place every problem on the wrong line;
diagnostics come from the language server, which converts those spans correctly
against the open document.

There is no formatter and no workspace symbol list: no `kofun fmt` exists, and
the server does not read unopened files, so a workspace symbol list would be
silently partial. Rename is provided, but only for locals and parameters, for
that same reason — see above.

## Commands

- **Kofun: Restart Language Server** — stops and restarts the bundled server.
- **Kofun: Show Language Server Output** — opens the server's output channel,
  which is also what the status-bar item opens when clicked.

A status-bar item reports whether the server is starting, running, or stopped,
because a server that died is otherwise invisible until a request quietly
returns nothing.

## Building

```sh
git submodule update --init vendor/kofun   # the pinned hjosugi/kofun checkout
npm run vendor-server                      # copy the server out and build its bundle
npm test                                   # manifest and end-to-end client tests
```

`vendor-server` builds the host Node-API producer bridge and stages the audited
codec/projector beside the bundled server, so run it before opening this folder
in VS Code's extension development host or packaging a VSIX. A C11 compiler and
Node headers are required; set `NODE_INCLUDE_DIR` only when the headers are
outside the Node installation prefix and the standard include locations.

To develop against a working tree of kofun rather than the pinned commit, point
`KOFUN_CHECKOUT` at it. To run a server built somewhere else entirely, set
`kofun.languageServer.path`; the bundled one is used otherwise.

## Platforms

The bundled server loads a native bridge compiled from kofun's
`native/semantic_bridge.c`, so a build only runs on the platform that produced
it. Releases are therefore built per platform and stamped with `--target`, and
VS Code offers each user only the build that matches their machine. Installed
on the wrong platform, the server answers every request with `null` — no
diagnostics, no hover, no completion, and neither an error nor the syntactic
fallback label — so the extension looks installed and does nothing. The
`--target` stamp is what prevents that, not a convenience.

`linux-x64`, `darwin-x64` and `darwin-arm64` are built. Windows is not: the
bundle is produced by a POSIX `sh` script invoking `cc`, which the Windows
runners do not provide.

## Releasing

`scripts/package-extension.sh [version] [target]` builds the VSIX into `dist/`.
It refuses a version that disagrees with `package.json`, so a tag, a workflow
input and the manifest cannot drift apart silently. Omitting the target
produces an unstamped VSIX, which is useful for local installation and wrong
for a release.

Publishing runs from the **Extension Package** workflow, which packages every
platform on each dispatch and publishes only when asked. All the platform
builds are published in one call, so a version never exists for some platforms
and not others. It reads `VSCE_PAT`, or performs an Azure login when the
`VSCE_AUTH_MODE` repository variable is `azure`; credentials are checked before
anything is uploaded rather than after.

Those credentials have to belong to the `hjosugi` publisher account, since
`publisher` is not free-form — it names an account the marketplace already
holds, and a PAT scoped elsewhere cannot publish under it. The account is the
one prerequisite the pipeline cannot create for itself.

## License

Licensed under [Apache-2.0](LICENSE-APACHE) or [MIT](LICENSE-MIT), at your
option — the same terms as the code this repository was split out of.
