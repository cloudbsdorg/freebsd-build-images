# Project Guidelines: freebsd-build-images

## Build/Configuration Instructions

This project manages the creation of FreeBSD-based container images for various OpenJDK versions and base build environments.

### Prerequisites

* **Operating System**: FreeBSD (tested on 14.x, 15.x, 16.x).
* **Tools**: 
    - `podman`: Container engine. Note that on FreeBSD, `podman` usually requires `sudo` for rootless mode or for regular image management.
    - `make`: For automation.
    - `bc`: Required by the `Makefile` for version comparisons.
    - `git`: For cloning the ports collection.

### Core Configuration

The project is configured via the `Makefile` in the root directory. Key variables include:

- `ORG`: The container registry organization (default: `cloudbsd`).
- `DOMAIN`: The container registry domain (default: `docker.io`).
- `FREEBSD_VERSIONS`: The FreeBSD releases to build for (e.g., `15.0 14.3 14.2`).
- `ARCHITECTURES`: Target architectures (e.g., `amd64 aarch64`).
- `DNS`: DNS server(s) to use for `podman build` (e.g., `8.8.8.8,1.1.1.1`). Default: `8.8.8.8, 8.8.4.4, 1.1.1.1, 1.0.0.1`.
- `DIRS`: Automatically discovered image directories by looking for folders with a `RELEASES` file (e.g., `java/openjdk21`, `www/node23`).

### Build Process

1. **Pre-build check**:
   ```bash
   make prebuild
   ```
2. **Ports setup**: The `ports/` directory requires the FreeBSD ports collection.
   ```bash
   make fetch-ports
   ```
   *Note: This will clone the ports tree into `ports-tree/` if missing, or update it with `git pull` if it exists. If the update fails, it will automatically perform a clean refetch.*

3. **Building images**:
   - Build all images: `make build` (requires `ports` and `pkg` images to be built/pushed).
   - Build specific images: The Makefile follows a dependency chain: `ports` -> `pkg` -> application image.
   - **Build Reporting**: The build process tracks successes and failures in a dated `.build_report_YYYYMMDD_HHMMSS` file and provides a summary at the end. Failures in one image will not stop the entire build process.

## Testing Information

Tests in this project consist of verifying that new images can be built successfully against supported FreeBSD releases.

### Adding a New Image

To add a new image (e.g., a new category or software version):
1. Create a directory following the ports structure (e.g., `www/node23` or `java/openjdk26`).
2. Add a `Containerfile` specifying the build steps.
3. Add a `RELEASES` file listing supported `version:architecture` pairs (one per line).
4. The `Makefile` will automatically detect the new directory (via the `DIRS` variable) and include it in the build process if it's listed in `RELEASES`.

### Running a Test Build

Before submitting changes, verify your `Containerfile` with a manual build:

```bash
# Example for a hypothetical 'myimage' directory
sudo podman build --build-arg FREEBSD_RELEASE=14.3 --build-arg ARCHITECTURE=amd64 -f myimage/Containerfile -t test-myimage:14.3
```

### Automated Test Example

You can run a quick verification of the build environment by building a minimal FreeBSD-based image:

```bash
# Verify FreeBSD container environment
mkdir -p test-verify
cat <<EOF > test-verify/Containerfile
ARG FREEBSD_RELEASE=14.3
FROM ghcr.io/freebsd/freebsd-runtime:\${FREEBSD_RELEASE}
RUN echo "Testing build on \$(uname -a)"
EOF

sudo podman build --build-arg FREEBSD_RELEASE=14.3 -t test-verify:latest ./test-verify
sudo podman run --rm test-verify:latest echo "Build and Run Verified"
sudo podman rmi test-verify:latest
rm -rf test-verify
```

## Additional Development Information

### Code Style and Standards

* **Containerfiles**:
    - Use `ARG` for versioning (`FREEBSD_RELEASE`, `ARCHITECTURE`).
    - Prefer installing packages via `pkg` first, with a fallback to building from source in `/usr/ports`.
    - Use `env ASSUME_ALWAYS_YES=yes IGNORE_OS_VERSION=yes pkg` for automated package management.
* **Makefile**:
    - The `DIRS` variable dynamically discovers image directories by looking for any folder containing a `RELEASES` file.
    - Ensure all new images follow the naming convention: `${DOMAIN}/${ORG}/${IMGBASE}-${IMGNAME}-${ARCH}:${VERSION}`, where `${IMGNAME}` is the directory path with `/` replaced by `-`.

### Debugging

- If `pkg` fails, check if the `FREEBSD_RELEASE` version matches the available packages for that architecture in the official FreeBSD mirrors.
- Use `sudo podman logs <container_id>` if a build step hangs or fails mysteriously.
