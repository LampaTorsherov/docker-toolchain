# Tango Docker images (linux/amd64)

Tango source for all ten builds: `https://github.com/LampaTorsherov/tango.git`.

- 1.26.4: commit `0651925c427ca1066c6777eb9a484015f027d697` (original Tango with optional LLVM integration).
- 1.26.11: tag `refs/tags/tango1.26.11` in the same fork.
- Both use the corresponding official Go image as bootstrap; no local Tango checkout is necessary.
- TangoLLVM also fetches the separate customized LLVM 19 repository, `https://github.com/bytedance/tangollvm.git`. Its default branch ref is `refs/heads/release/tangollvm19.x`; override `TANGOLLVM_REF` with a full commit SHA to pin it. `TANGOLLVM_REPO` can point at your mirror.

## Files and tags

| Dockerfile | Image tag |
|---|---|
| `Dockerfile.tangolang-1.26.11-alpine` | `tangolang:1.26.11-alpine` |
| `Dockerfile.tangolang-1.26.11-bookworm` | `tangolang:1.26.11-bookworm` |
| `Dockerfile.tangolang-1.26.11-trixie` | `tangolang:1.26.11-trixie` |
| `Dockerfile.tangolang-1.26.4-alpine` | `tangolang:1.26.4-alpine` |
| `Dockerfile.tangolang-1.26.4-bookworm` | `tangolang:1.26.4-bookworm` |
| `Dockerfile.tangolang-1.26.4-trixie` | `tangolang:1.26.4-trixie` |
| `Dockerfile.tangolang-llvm-1.26.11-bookworm` | `tangolang-llvm:1.26.11-bookworm` |
| `Dockerfile.tangolang-llvm-1.26.11-trixie` | `tangolang-llvm:1.26.11-trixie` |
| `Dockerfile.tangolang-llvm-1.26.4-bookworm` | `tangolang-llvm:1.26.4-bookworm` |
| `Dockerfile.tangolang-llvm-1.26.4-trixie` | `tangolang-llvm:1.26.4-trixie` |

## Building from another repository

Copy only the Dockerfile(s) into the image-builder repository. A regular BuildKit build works even with an empty context, because no `COPY .` is used.

```sh
docker buildx build --platform linux/amd64 --load \
  -f Dockerfile.tangolang-1.26.11-trixie \
  -t tangolang:1.26.11-trixie .
```

Resolve the LLVM source revision once in CI and use the same SHA for all LLVM variants:

```sh
LLVM_SHA=$(git ls-remote https://github.com/bytedance/tangollvm.git \
  refs/heads/release/tangollvm19.x | cut -f1)
test "${#LLVM_SHA}" -eq 40

docker buildx build --platform linux/amd64 --load \
  --build-arg TANGOLLVM_REF="$LLVM_SHA" \
  --build-arg LLVM_JOBS=2 \
  --build-arg LLVM_RUN_REGRESSION_TESTS=1 \
  -f Dockerfile.tangolang-llvm-1.26.11-bookworm \
  -t tangolang-llvm:1.26.11-bookworm .
```

Use `--push` instead of `--load` and the desired registry-prefixed tag when publishing with buildx. LLVM builds are resource-intensive; provision enough free disk for the LLVM source, object files, SDK and image layers, and avoid parallel LLVM builds on the same small runner. Consider sharing BuildKit cache between the two Go versions for each base distribution.

## Build arguments

| Argument | Scope | Purpose |
|---|---|---|
| `BOOTSTRAP_IMAGE` | all | official Go image, override for a mirror |
| `BASE_IMAGE` | all | final distro base (also LLVM build base for LLVM images) |
| `TANGO_REPO` | all | Tango source repository |
| `TANGO_REF` | all | pinned source ref; Go and Tango versions are still checked |
| `TANGOLLVM_REPO` | LLVM | customized LLVM source repo |
| `TANGOLLVM_REF` | LLVM | LLVM ref; a full commit SHA is strongly recommended |
| `LLVM_JOBS` | LLVM | C++ build and install concurrency, default 2 |
| `LLVM_RUN_REGRESSION_TESTS` | LLVM | 1 runs the upstream `test/llvm/test.sh 3 3 1`, default 0 |

## Image contents and use

All final images use `/usr/local/go` (GOROOT), `/go` (GOPATH and WORKDIR), and `GOTOOLCHAIN=local`. Debian variants include C/C++ and pkg-config; plain Alpine is minimal. LLVM images are provided only for Debian Trixie and Bookworm; LLVM Alpine is intentionally excluded. Both LLVM variants have the actual customized LLVM tools, shared library, headers and licenses under `/usr/local/go/pkg/tangollvm`. Git history, bootstrap Go, CMake build objects, and download/build caches are not copied into final images. `TANGO_REVISION`, `TANGOLLVM_REVISION` (LLVM only) and `tangollvm-source.json` (LLVM only) are retained.

Ordinary Tango:

```sh
go build -opt=beast ./...
```

LLVM image (experiment enabled by default, backend still needs compiler flags):

```sh
GOEXPERIMENT=tangollvm CGO_ENABLED=1 go build \
  -gcflags='all=-beast=llvm=3,optimize=3,inline=1' ./...
```

Standard backend inside LLVM image:

```sh
GOEXPERIMENT=notangollvm go build ./...
```

Full LTO needs a fresh build of all packages per upstream docs:

```sh
GOEXPERIMENT=tangollvm CGO_ENABLED=1 go build -a \
  -gcflags='all=-beast=llvm=3,optimize=3,inline=1,full-lto=1' ./...
```

The LLVM build uses the upstream `build.sh` and official `make.tangollvm.bash`. The only adaptations to `build.sh` are lower job parallelism, limiting concurrent links, disabling LLVM's own tests/benchmarks/examples and optional system-library integrations. The customized LLVM source and Go backend code are not patched. A real LLVM example is built and executed in the final stage; the standard backend is also smoke-tested. A successful normal Tango update does not establish LLVM compatibility. Full LLVM regression suite is optional but recommended for a production tag, especially for 1.26.11.

These Dockerfiles were statically checked, not built in Docker locally. LLVM branch HEAD and base image tags can change. Pin LLVM SHA and optionally OCI digests of the base images for repeatability. No claim is made of bit-for-bit reproducible binaries.
