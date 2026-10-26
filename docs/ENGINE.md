# WORDS engine build and provenance

Source: https://github.com/mk270/whitakers-words

Pinned revision: `1f2f0fb0867a896d7b9284a03d615ed635d6f992`. Upstream documentation: https://mk270.github.io/whitakers-words/. License copied unchanged in [WORDS-LICENCE.txt](WORDS-LICENCE.txt).

The packaged executable is ARM64, targets macOS 14 and links the Ada runtime statically. Its only external dynamic library is Apple's libSystem. Generated dictionary data is rebuilt together with the executable; do not mix the old Intel engine's binary data with this version. `engine-manifest.json` records source, compiler, SDK, local patch and packaged file hashes.

## Rebuild

Install native Apple-silicon GNAT with GPRBuild, or extract a toolchain package into a local directory. The tested toolchain is [Simon Wright's GCC 14.2.0-3 aarch64 macOS distribution](https://github.com/simonjwright/distributing-gcc/releases/tag/gcc-14.2.0-3-aarch64). Its `.pkg` can be expanded without system installation using `pkgutil --expand-full package.pkg /private/tmp/iwords-gnat`; use the expanded inner package's `Payload` directory as GNAT_ROOT. Python 3, Git, make and Xcode command-line tools are also required.

If command-line tools point to a standalone installation, set `DEVELOPER_DIR` to your Xcode app’s `Contents/Developer` directory to select its SDK without changing system-wide settings.

From the repository root:

```sh
GNAT_ROOT=/absolute/path/to/toolchain/Payload python3 scripts/build-engine.py
python3 scripts/test-engine.py
```

The build script clones into the disposable, ignored `.build/words-source`, checks out the pinned revision, applies the checked-in patch, builds with the selected Xcode SDK and minimum macOS 14, verifies architecture/linkage, removes toolchain rpaths, signs the engine ad-hoc with hardened runtime, and updates the bundled executable, matching data and manifest. Only runtime dictionary data is packaged. The source dictionary, intermediate lists and generation diagnostics remain in the disposable build checkout; they are not needed for app lookup or dictionary relocation. It preserves iWords' `WORD.MDV` protocol configuration. Review and commit those generated changes together when updating the engine. The build checkout is disposable; do not develop upstream changes there.

`words-no-trampoline.patch` replaces a nested callback iteration with equivalent direct cursor iteration. GNAT's ARM64 trampoline implementation otherwise fails under macOS hardened runtime. This avoids granting executable-memory exceptions. The patch does not intentionally change linguistic processing.

The portable regression runner uses the five pinned upstream fixtures and upstream header/footer and whitespace normalization. It runs the packaged, hardened-runtime-signed engine in a temporary data directory. Xcode tests additionally cover the actual asynchronous app protocol, repeated requests in both directions, single letters, irregular forms, enclitics, unknown input, serialized requests, cancellation, timeout, output limits and child-process cleanup.

## Data migration

Preferences live under `Application Support/iWords/Settings-v1/WORD.MDV`, with an atomic `migration.json` recording schema version and whether custom preferences are enabled. The migration checks the previous ARM directory first, then the Intel-era directory, and carries over only the five supported Y/N filtering preferences. Protocol flags come from the current bundled defaults. Old files are preserved. Unknown schema versions are rejected without overwriting them; interrupted migrations can be retried.

Dictionary data stays in the signed app bundle. Each lookup batch receives a temporary workspace with links to bundled data and a copy of its settings snapshot. The adapter removes that workspace after completion, failure or cancellation. Disabling custom settings preserves saved preferences and records the disabled state so legacy settings are not silently re-imported on launch.

`WordsEngine` holds an explicit FIFO gate across actor suspension points. Queued requests can cancel without waiting for the active request. Each process has a five-second response deadline and a four-MiB combined stdout/stderr limit. Reads use fixed-size nonblocking buffers; completion requires the response prompt after the language-change prompt. Cleanup sends termination, escalates to SIGKILL after 200 ms if necessary, and reaps the child before advancing the queue. Starting a new process per word trades launch overhead for isolation between requests.

## Accessory utility provenance

The original project introduced Flow from https://github.com/alexito4/Flow in commit `fe08e9b`, then removed its direct package reference in `00a59f1`. Commit `1af1401` replaced local utilities with DWUtils from a sibling checkout. The active sources no longer rely on either library: construction uses ordinary Swift statements, font conversion uses NSFontManager, window positioning uses NSWindow frame coordinates, and defaults/debug behavior uses Foundation. Historical source attribution remains in Git; no unattributed vendored Flow implementation is introduced.
