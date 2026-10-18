# Muak extension images
#
# Prerequisites: docker/podman, just, git
# Run `just --list` for available recipes

set shell := ["bash", "-euo", "pipefail", "-c"]
set script-interpreter := ["bash", "-euo", "pipefail"]
set positional-arguments

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Global settings

registry := env_var_or_default("REGISTRY", "ghcr.io/muak-os")
tag := env_var_or_default("TAG", "dev")
toolchain := env_var_or_default("TOOLCHAIN", "ghcr.io/muak-os/toolchain@sha256:c18a288141bf4745151ae83d0d5f05d875a102c5348a12d5ab89fa94b4f1c3a0")
alpine_version := "3.24"
push := env_var_or_default("PUSH", "true")
extension := env_var_or_default("EXTENSION", "qemu")

# Architecture

[private]
_arch_env := env_var_or_default("ARCH", "x86_64")
arch := if _arch_env == "amd64" { "x86_64" } else if _arch_env == "arm64" { "aarch64" } else { _arch_env }
oci_arch := if arch == "aarch64" { "arm64" } else if arch == "x86_64" { "amd64" } else { arch }

# Extension image repository

extension_repository := if extension == "qemu" { "extensions/qemu" } else if extension == "firecracker" { "extensions/firecracker" } else if extension == "cloud-hypervisor" { "extensions/cloud-hypervisor" } else { error("unknown extension '" + extension + "'") }

# Container runtime

container_runtime := env_var_or_default("CONTAINER_RUNTIME", "podman")
build_cmd := if container_runtime == "podman" { "podman build" } else { "docker buildx build" }
pull_arg := if container_runtime == "podman" { "--pull=missing" } else { "" }
push_arg := if container_runtime == "podman" { "" } else { if push == "true" { "--push" } else { "" } }
provenance_arg := if container_runtime == "podman" { "" } else { "--provenance=false" }
common_args := "--platform=linux/" + oci_arch + " --progress=" + env_var_or_default("PROGRESS", "auto") + " --build-arg ALPINE_VERSION=" + alpine_version + " " + provenance_arg

# Colors

bold := '\e[1m'
cyan := '\e[36m'
green := '\e[32m'
red := '\e[31m'
reset := '\e[0m'

# ─────────────────────────────────────────────────────────────────────────────
# Build
# ─────────────────────────────────────────────────────────────────────────────

# Full local development build (oci -> repack)
[group('build')]
dev: oci repack
    @printf "{{ green }}Development build complete. Toolchain used: {{ bold }}{{ toolchain }}{{ reset }}\n"

# ─────────────────────────────────────────────────────────────────────────────
# OCI Images
# ─────────────────────────────────────────────────────────────────────────────

# Build (and optionally push) the extension OCI image
[group('oci')]
oci:
    @just _build-oci "{{ extension_repository }}" "{{ extension }}"
    @printf "{{ green }}Extension image built: {{ registry }}/{{ extension_repository }}:{{ tag }}{{ reset }}\n"

# Merge per-platform images into a multi-arch OCI index
[group('oci')]
[script]
merge *sources:
    {{ container_runtime }} run --rm --network=host \
        -e KOCI_REGISTRY_USERNAME -e KOCI_REGISTRY_PASSWORD \
        {{ toolchain }} \
        /koci merge \
            --image "{{ registry }}/{{ extension_repository }}" \
            --tag "{{ tag }}" \
            {{ sources }}

# Repack an OCI image's layers into eStargz, in place.
[group('oci')]
[arg("image", long="image")]
repack image=(registry + "/" + extension_repository + ":" + tag):
    @printf "{{ cyan }}Repacking OCI image {{ image }}{{ reset }}\n"
    {{ container_runtime }} run --rm --network=host \
        -e KOCI_REGISTRY_USERNAME -e KOCI_REGISTRY_PASSWORD \
        {{ toolchain }} \
        /koci repack \
            --image "{{ image }}"

# ─────────────────────────────────────────────────────────────────────────────
# Private Helpers
# ─────────────────────────────────────────────────────────────────────────────

[private]
[script]
_build-oci name extension:
    image="{{ registry }}/{{ name }}:{{ tag }}"
    cache_from=$(just _cache-from "{{ name }}")
    cache_to=$(just _cache-to "{{ name }}")
    printf "{{ cyan }}Building OCI:{{ reset }} {{ name }} (push={{ push }})\n"
    {{ build_cmd }} {{ common_args }} {{ pull_arg }} \
        ${cache_from} ${cache_to} {{ push_arg }} --tag "${image}" \
        --file {{ extension }}/Dockerfile \
        {{ extension }}
    if [ "{{ container_runtime }}" = "podman" ] && [ "{{ push }}" = "true" ]; then
        {{ container_runtime }} push "${image}"
    fi

[private]
_cache-from name:
    @if [ "{{ env_var_or_default("GITHUB_ACTIONS", "false") }}" = "true" ]; then printf '%s' "--cache-from=type=registry,ref={{ registry }}/{{ name }}:buildcache-{{ oci_arch }}"; fi

[private]
_cache-to name:
    @if [ "{{ env_var_or_default("GITHUB_ACTIONS", "false") }}" = "true" ] && [ "{{ push }}" = "true" ]; then printf '%s' "--cache-to=type=registry,ref={{ registry }}/{{ name }}:buildcache-{{ oci_arch }},mode=max"; fi
