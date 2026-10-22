# Vivado on macOS with Colima

macOS uses `../scripts/vivado` to run Linux amd64 Vivado in Docker. Linux uses
native `vivado` through the same wrapper; `Makefile.win` continues to run native
Windows Vivado. Docker and Colima are only required on macOS.

## Prerequisites and initial setup

Install the Docker CLI, Colima, GNU Make and Bash (for example,
`brew install colima docker make`). On Apple Silicon, the reference setup uses
Apple's Virtualization framework with Rosetta and virtiofs. Install Rosetta if
macOS requests it. The repository and license must be accessible through the
VM's host shares; Colima normally shares your home directory writable.

The implementation was adapted from `nn2hl/vivado/docker`. That directory supplies
the runtime wrapper, the udev workaround and a derived Dockerfile, **not a Vivado
installer or a base-image build**. Vivado is already installed in a named Docker
volume, mounted at `/opt/Xilinx`. The other volume holds `/root/.Xilinx` state.

Reuse an existing `vivado` profile first:

```bash
colima status --profile vivado
# From this repository root; starts only a saved profile, with its saved settings:
make vivado-start
docker --context colima-vivado image inspect vivado-runtime:2026.1-rosetta
docker --context colima-vivado volume inspect vivado-2026.1 vivado-2026.1-user
```

The inspected reference profile has 6 CPUs, 8 GiB memory and a 250 GiB data disk,
with `arch: aarch64`, `runtime: docker`, `vmType: vz`, `rosetta: true` and
`mountType: virtiofs`. Its provisioning list is empty. These are existing settings,
not allocations made by this repository. Startup supplies no resource flags and
does not change the active Docker context. Normal invocations only check Docker;
they do not start, resize or reinitialize the VM.

On a new Apple Silicon machine only, create a profile explicitly, choosing
resources and disk capacity suitable for your Vivado installation. For example:

```bash
colima start --profile vivado --arch aarch64 --runtime docker --vm-type vz \
  --vz-rosetta --mount-type virtiofs --cpus 4 --memory 8 --disk 100 --activate=false
```

Do not run this creation command over an existing profile. Intel Macs need a
compatible amd64 VM/runtime rather than the Apple Silicon Rosetta configuration.
For project/build/license directories outside the default home share, configure
writable mounts in the saved Colima configuration before starting it.

Provision or restore the licensed Linux Vivado installation and runtime image
separately, including the device support for your board (7 Series for Nexys A7).
Loading an image alone does not restore its installation/user volumes. The
wrapper checks that both volumes exist before running; it never creates them or
downloads an image. Obtain the base `vivado-runtime:2026.1` image from your working
setup if rebuilding the Rosetta workaround image:

```bash
docker --context colima-vivado build --platform linux/amd64 \
  -f fpga/docker/Dockerfile.runtime -t vivado-runtime:2026.1-rosetta fpga/docker
```

This optional build only adds `udev_stub.c` to that existing base image. It does
not install Vivado. Keep the existing license at `~/.licenses/xilinx/Xilinx.lic`,
or configure `FPGA_LICENSE_FILE`; it is mounted read-only. The fixed container MAC
address matches the reference runtime and is configurable for your license.

## Configuration

Set environment variables, Make command-line variables, or untracked
`fpga/local.mk` entries such as `FPGA_LICENSE_FILE = /absolute/path/Xilinx.lic`.
Use absolute paths for machine-local configuration. The Makefile exports these
options to the wrapper:

| Option | Default |
| --- | --- |
| `FPGA_RUNTIME` | `auto`: Docker on Darwin, native elsewhere |
| `VIVADO_NATIVE` | `vivado` (native executable path) |
| `FPGA_COLIMA_PROFILE` | `vivado` |
| `FPGA_DOCKER_CONTEXT` | `colima-<profile>` |
| `FPGA_DOCKER_IMAGE` | `vivado-runtime:2026.1-rosetta` |
| `FPGA_DOCKER_INSTALL_VOLUME` | `vivado-2026.1` |
| `FPGA_DOCKER_USER_VOLUME` | `vivado-2026.1-user` |
| `FPGA_DOCKER_SETTINGS` | `/opt/Xilinx/2026.1/Vivado/settings64.sh` |
| `FPGA_DOCKER_MAC_ADDRESS` | `02:42:ac:11:00:02` |
| `FPGA_LICENSE_FILE` | `~/.licenses/xilinx/Xilinx.lic` |

`COLIMA_HOME` can select a different Colima configuration directory. For an
existing `VIVADO` Make override, that command still takes precedence over the
wrapper. Native Linux and Windows users can continue setting `VIVADO` as before.

## Validate, then build

From the repository root, run this lightweight check first:

```bash
make vivado-check
cat build/vivado-check.txt
ls -l build/vivado-check.txt
```

It starts Vivado in batch mode, prints the version and forwarded flow variables,
checks that both source lists and include paths exist, and writes a host-visible
file. It does not create a Vivado project or synthesize RTL. Missing dependencies
require `make repository_init`; regenerate lists with `make -C fpga gen_filelists`
if their paths have changed. A successful check leaves `build/vivado-check.log`
and `build/vivado-check.txt`. Files should be writable by your macOS account;
the existing Colima virtiofs share maps container writes to the host user. Check
this when changing VM/share configuration.

Then follow the existing firmware and FPGA workflow when ready for a full build:

```bash
cd fpga
make build_test TEST=pixel_inversion
make all_xilinx TEST=pixel_inversion
# Equivalent FPGA invocation from the repository root: make fpga TEST=pixel_inversion
```

For synthesis only, use `make syn TEST=pixel_inversion` from the repository root,
or `make synth_xilinx TEST=pixel_inversion` from `fpga/`. This stops after a
successful synthesis run, before implementation or bitstream generation.
The current `compile`, `elaborate` and simulation targets use Questa; the Vivado
container does not provide their `vlib`, `vlog`, `vopt` or `vsim` commands.

Software compilation still uses the host RISC-V toolchain. Synthesis,
implementation, bitstream generation and reporting remain in `run_xilinx.tcl`.
The default project/bitstream path is `build/fpga/<PROJECT>/`, firmware inputs
are in `build/fpga/sw/`, and reports are in `build/fpga/logs/`.
`BUILD_DIR` overrides now apply to all three. Use an absolute path when sharing a
custom build directory across invocations; external build directories are mounted
separately at the same path.

The entire repository (including `.bender`, `vendor_ips`, generated RTL and
build outputs) is mounted writable at its identical host path. The container uses
the caller's working directory, normally `fpga/`. Absolute arguments and Tcl
paths therefore resolve directly; relative file lists work unchanged.
`PROJECT`, `TEST`, `ACC_LANG` and normalized `BUILD_DIR` are forwarded explicitly.
Other external absolute input paths need an appropriate bind mount; keep inputs
in the repository. Each command creates a disposable container using the same
installed volumes, then propagates Vivado's exit status through Docker and Make.
No persistent container or repeated installation is needed. Make may translate
a failing recipe's exit code to its own nonzero status.

The headless runtime rejects `all_xilinx_gui`. Its udev stub disables USB/JTAG
discovery to avoid Rosetta crashes. Use a separate supported programmer or native
Vivado on Linux/Windows for board programming and GUI inspection. Native GUI
targets remain available.

## Troubleshooting

- Docker unavailable: check `docker --context colima-vivado info` and run
  `make vivado-start`. The explicit context avoids accidentally using Docker Desktop.
- Image/volume missing: restore them in that context; do not create an empty
  replacement installation volume. Check the configurable names above.
- Settings unreadable: confirm the installation volume layout and set
  `FPGA_DOCKER_SETTINGS` to its actual `settings64.sh` path.
- License failure: check `FPGA_LICENSE_FILE`, license validity and the configured
  MAC address. The wrapper does not alter license contents.
- Bind mount missing or output unwritable: check the VM's saved host shares and
  permissions. `--mount` fails on missing sources instead of creating empty VM paths.

Mocked wrapper checks (no Docker or Vivado required):
`python3 -m unittest discover -s fpga/tests -v`.
