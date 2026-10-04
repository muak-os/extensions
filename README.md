# muak-os/extensions

Extension images for [muak](https://github.com/muak-os/muak).

## Extensions

| Extension | Binary | Version |
| --------- | ------ | ------- |
| [QEMU](qemu/) | `qemu-system-x86_64`, `qemu-system-aarch64`, `qemu-img` | `9.2.0` |
| [Firecracker](firecracker/) | `firecracker` + kernel and rootfs | `1.13.0` |
| [Cloud Hypervisor](cloud-hypervisor/) | `cloud-hypervisor` (+ `CLOUDHV.fd` on x86_64) | `42.0` |

Images are published to `ghcr.io/muak-os/extensions/<extension>` in `amd64` and `arm64`.

## Local Development

A local OCI registry makes iterative testing easy:

```sh
podman run -d -p 5000:5000 --name registry docker.io/library/registry:3

REGISTRY="localhost:5000" EXTENSION=qemu PUSH=true LATEST=true just build
```
