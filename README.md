# freebsd-build-images

Collection of Containerfiles and building logic for FreeBSD-based build environments, organized as a FreeBSD Containers collection.

## Overview

This repository provides the infrastructure to build container images for FreeBSD that include:
- Base build toolchain
- FreeBSD Ports collection
- FreeBSD source tree
- OpenJDK (versions 8 through 25, in `java/`)
- NodeJS (versions 18, 20, 22, 23, in `www/`)

The images are built using `podman` and are organized in a tiered fashion:
1. **Ports Tree Image**: Based on `ghcr.io/freebsd/freebsd-toolchain`, it includes the FreeBSD ports collection.
2. **Pkg Image**: Based on the Ports Tree image, it bootstraps `pkg`, installs `git`, and clones the FreeBSD source tree.
3. **Application Images**: Based on the Pkg image, these install specific software (e.g., OpenJDK, NodeJS) from the FreeBSD ports/packages.

## Requirements

- **Podman**: Used for building and pushing images.
- **Make**: Used for build orchestration.
- **Git**: To clone the ports collection and source tree during the build process.
- **BC**: Used in the Makefile for version comparison logic.

## Project Structure

The project is organized similarly to the FreeBSD ports collection:

```text
.
├── Makefile                # Build orchestration and automation
├── pkg/                    # Core image with pkg, git, and freebsd-src
│   └── Containerfile
├── ports-tree/             # Image containing the ports tree
│   ├── Containerfile
│   └── ports/              # (Cloned during build) FreeBSD ports collection
├── java/                   # Java-related images
│   └── openjdk[N]/         # Specific OpenJDK version images
│       ├── Containerfile
│       └── RELEASES
├── www/                    # Web-related images
│   └── node[N]/            # Specific NodeJS version images
│       ├── Containerfile
│       └── RELEASES
├── test-img/               # Testing/verification image
└── README.md
```

## Build & Run

The build process is managed by the `Makefile`. By default, it builds for the current architecture and the FreeBSD versions specified in the `Makefile`.

### Common Commands

- **Build all images**:
  ```bash
  make build
  ```
  *Note: This will trigger building ports and pkg images first if they are not already built/pushed.*

- **Build specific components**:
  ```bash
  make build-ports-tree  # Build only the ports tree image
  make build-pkg         # Build only the pkg image
  ```

- **Push images to registry**:
  ```bash
  make push
  ```

- **Create and push multi-arch manifests**:
  ```bash
  make manifestmerge
  ```

- **Cleanup**:
  ```bash
  make clean
  ```

### Build Reporting

The `Makefile` implements a reporting mechanism to track the status of image builds and pushes.

- **Non-blocking builds**: If a `podman build` fails, the script continues to build other requested images.
- **Reporting**: Successes and failures are recorded in a dated `.build_report_YYYYMMDD_HHMMSS` file.
- **Summary**: At the end of a `build` or `push` target, a summary report is printed to the console.
- **Exit Status**: If any component fails to build or push, the final `make` command will exit with a non-zero status code after showing the full report.

### Build Parameters

You can override default values by passing them to `make`:

| Variable | Default | Description |
|----------|---------|-------------|
| `ORG` | `cloudbsd` | Container registry organization/user |
| `DOMAIN` | `docker.io` | Container registry domain |
| `IMGBASE` | `freebsd-build` | Base name for the generated images |
| `FREEBSD_VERSIONS` | `16.snap 15.0 14.3 14.2` | List of FreeBSD releases to build for |
| `ARCHITECTURES` | `amd64 aarch64` | List of target architectures for manifests |
| `DNS` | `8.8.8.8, ...` | DNS server(s) to use (comma or space separated) |

Example:
```bash
make ORG=myrepo build
```

## Supported Releases

Each OpenJDK directory contains a `RELEASES` file that specifies which FreeBSD version and architecture combinations are supported for that specific JDK version.

- **FreeBSD Releases**: 16.snap, 15.0, 14.3, 14.2
- **Architectures**: amd64, aarch64

## Scripts and Automation

- **`fetch-ports` target**: Clones the FreeBSD ports tree into `ports-tree` if it doesn't exist, or updates it with `git pull` if it already exists. If the local directory is corrupted or the update fails, it automatically performs a clean refetch.

## Submodule Consideration

While the ports tree is currently managed via a separate clone/pull (and ignored by git), you could convert it to a submodule if you need to pin it to a specific version. To do so:
1. Remove `/ports-tree/` from `.gitignore`.
2. Run `git submodule add https://github.com/freebsd/freebsd-ports.git ports-tree`.
3. The `Makefile` will still be able to update it with `git pull`, though you may prefer `git submodule update --remote`.

- **`manifestmerge`**: Uses `podman manifest` to create multi-arch images by combining architecture-specific tags into a single manifest under the base tag (e.g., `cloudbsd/freebsd-build-openjdk21:14.3`).

## Tests

- **`test-img/`**: Contains a Containerfile and RELEASES file for a test image.
- **TODO**: Implement automated validation scripts to verify JDK installations within the built images.

## Environment Variables

The Makefile uses several variables to control the build process. While not environment variables in the strict OS sense, they can be passed as arguments to `make` or set in the environment.

- `FREEBSD_VERSIONS`: Space-separated list of FreeBSD versions.
- `ARCHITECTURES`: Target architectures for multi-arch manifests.

## License

This project is licensed under the BSD 3-Clause License. See the [LICENSE](LICENSE) file for details.
