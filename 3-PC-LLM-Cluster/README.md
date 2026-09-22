# 3-PC LLM Cluster — Beginner-Friendly Guide

Use **three computers together to run one local Large Language Model (LLM)**, or use all three machines to process independent AI jobs in parallel.

This guide is written for non-experts. It explains the hardware, network, software, setup, testing, troubleshooting, and two practical architectures:

1. **One model split across three PCs** — useful when the model is too large for one computer.
2. **One model per PC** — useful when you have many independent jobs and want higher throughput.

> **Important:** Three PCs do not become one physical GPU. The computers remain separate and exchange data over the network. Network speed therefore matters.

## Architecture

![Three-PC LLM Cluster](NETWORK_DIAGRAM.svg)

### Option A — One LLM split across three PCs

```text
                    ┌─────────────────────────┐
                    │      10 GbE Switch      │
                    └───────┬───────┬─────────┘
                            │       │
                 ┌──────────┘       └──────────┐
                 │                             │
        ┌────────▼────────┐          ┌────────▼────────┐
        │ PC 1 — Main     │          │ PC 2 — Worker   │
        │ LLM UI/API      │          │ GPU / VRAM      │
        │ GPU / VRAM      │          │ RPC server      │
        └────────┬────────┘          └─────────────────┘
                 │
        ┌────────▼────────┐
        │ PC 3 — Worker   │
        │ GPU / VRAM      │
        │ RPC server      │
        └─────────────────┘
```

PC 1 is the machine you interact with. PC 2 and PC 3 expose their compute resources to PC 1.

### Option B — Three independent LLM workers

```text
                         Shared job queue
                               │
               ┌───────────────┼───────────────┐
               │               │               │
          ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
          │  PC 1   │     │  PC 2   │     │  PC 3   │
          │  LLM    │     │  LLM    │     │  LLM    │
          └─────────┘     └─────────┘     └─────────┘
```

This is often faster for batch workloads such as transcript summarization because the PCs do not need to communicate during every model operation.

## Which design should I choose?

| Requirement | Recommended design |
|---|---|
| Model fits on one GPU | Run it on one PC |
| Model does not fit on one PC | Split one model across PCs |
| Hundreds/thousands of independent jobs | One LLM per PC |
| Want easiest setup | Start with llama.cpp RPC |
| Need a more production-oriented multi-node stack | Consider vLLM + Ray |

## Hardware prerequisites

You need:

- 3 computers
- Wired Ethernet on every computer
- Preferably NVIDIA GPUs if you want CUDA acceleration
- Enough system RAM and storage for your model
- A switch/router connecting the computers
- The same model file available where required
- Compatible software versions on all three machines

### Network recommendation

| Network | Suitable? | Notes |
|---|---|---|
| Wi-Fi | Poor choice | Latency and instability can hurt distributed inference |
| 1 GbE | Testing only | Often becomes a bottleneck |
| 2.5 GbE | Usable | Better for experimenting |
| 10 GbE | Recommended home/lab baseline | Strong balance of cost and speed |
| 25/40/100 GbE | Excellent | More appropriate for serious servers |

## Physical connection

```text
PC 1 Ethernet ──┐
PC 2 Ethernet ──┼── Ethernet Switch ── optional router/internet
PC 3 Ethernet ──┘
```

For 10GBASE-T networking, Cat6a is a safe general-purpose cable choice.

## Stable IP addresses

Example lab addresses:

| Computer | Role | Example IP |
|---|---|---|
| PC 1 | Main/controller | 192.168.50.11 |
| PC 2 | Worker | 192.168.50.12 |
| PC 3 | Worker | 192.168.50.13 |

You can configure these as static IP addresses in Windows or create DHCP reservations in your router.

### Test connectivity

From PC 1:

```bat
ping 192.168.50.12
ping 192.168.50.13
```

If ping fails, fix networking before installing the LLM cluster.

## Inventory each PC

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Check-Cluster-PC.ps1
```

It reports the PC name, Windows version, CPU, RAM, IPv4 addresses, Ethernet link speed and NVIDIA GPU information when `nvidia-smi` is available.

# PART A — llama.cpp RPC

## What llama.cpp RPC does

llama.cpp has an RPC backend that can expose compute devices from remote hosts. The main llama.cpp process can then use local and remote accelerator devices for distributed inference.

The upstream documentation currently describes the RPC backend as **proof-of-concept / experimental** and warns not to expose the RPC server to an open or untrusted network.

Therefore:

- keep RPC traffic on your private LAN;
- do not port-forward the RPC port to the Internet;
- use Windows Firewall rules that limit access to your LAN;
- do not run it on an untrusted/public network.

References:

- https://github.com/ggml-org/llama.cpp
- https://github.com/ggml-org/llama.cpp/blob/master/tools/rpc/README.md

## Install prerequisites

For a source build on Windows you normally need:

- Git
- CMake
- Visual Studio Build Tools / C++ compiler
- NVIDIA CUDA toolkit if using NVIDIA CUDA acceleration
- Current NVIDIA driver

Official references:

- https://git-scm.com/
- https://cmake.org/
- https://visualstudio.microsoft.com/downloads/
- https://developer.nvidia.com/cuda-downloads

## Build llama.cpp with CUDA + RPC

```bat
git clone https://github.com/ggml-org/llama.cpp.git
cd llama.cpp

cmake -B build-rpc -DGGML_CUDA=ON -DGGML_RPC=ON
cmake --build build-rpc --config Release
```

The exact binary path can vary with build tools and llama.cpp versions. Check the current RPC README before running commands.

## Start PC 2 and PC 3 as workers

On PC 2 and PC 3, start the llama.cpp RPC server according to the current official RPC documentation.

Conceptually:

```text
PC 2 — 192.168.50.12 — RPC worker
PC 3 — 192.168.50.13 — RPC worker
```

Allow only the required executable/port from your private subnet through the firewall.

## Start the main LLM on PC 1

Conceptual example:

```bat
llama-server ^
  -m D:\Models\your-model.gguf ^
  -ngl 99 ^
  --rpc 192.168.50.12:PORT,192.168.50.13:PORT
```

Replace the model path, port and any model-specific arguments with values valid for your installed llama.cpp version.

llama.cpp documentation also describes `--tensor-split` for custom allocation.

## Understanding combined VRAM

Example:

```text
PC 1 GPU = 24 GB
PC 2 GPU = 24 GB
PC 3 GPU = 24 GB

Nominal total VRAM = 72 GB
```

This does **not** behave exactly like a single 72 GB GPU because of network transfer, synchronization, KV cache, context length, quantization, uneven GPUs and software overhead.

Always leave headroom.

# PART B — vLLM + Ray

vLLM supports distributed inference and serving using tensor parallelism and pipeline parallelism. Its multi-node documentation uses Ray as a distributed runtime.

References:

- https://github.com/vllm-project/vllm
- https://docs.vllm.ai/en/latest/serving/parallelism_scaling/
- https://github.com/ray-project/ray
- https://docs.ray.io/
- https://docs.ray.io/en/latest/cluster/getting-started.html

A conceptual three-node design:

```text
                         Ray Head
                          PC 1
                           │
                 ┌─────────┴─────────┐
                 │                   │
              Ray Worker          Ray Worker
                 PC 2                PC 3
```

vLLM deployments are commonly Linux-based. For a Windows home/lab setup, llama.cpp is generally the easier place to begin.

# Best design for batch processing

If each job is independent and the model fits on each PC, running one model on each machine can be faster:

```text
                     JOB QUEUE
          ┌─────────────┼─────────────┐
          │             │             │
        PC 1          PC 2          PC 3
      Video A       Video B       Video C
```

This reduces network synchronization and is well suited to large numbers of independent transcript or document jobs.

## Recommended setup sequence

1. Inventory all three PCs.
2. Connect them with wired Ethernet.
3. Assign stable IP addresses.
4. Verify ping between every machine.
5. Confirm actual negotiated Ethernet speed.
6. Confirm GPUs with `nvidia-smi`.
7. Run one model successfully on PC 1.
8. Add one RPC worker.
9. Test generation and stability.
10. Add the third PC.
11. Compare performance against the one-PC baseline.
12. Tune model size, context length and allocation only after the basic cluster works.

## Performance testing

Record:

- model name
- GGUF quantization
- context size
- prompt size
- generated token count
- time to first token
- tokens per second
- GPU memory on each PC
- Ethernet throughput
- CPU utilization

Compare PC 1 alone, PC 1 + PC 2, and all three PCs.

## Useful Windows commands

```bat
ipconfig
ping 192.168.50.12
nvidia-smi
nvidia-smi -l 1
```

```powershell
Get-NetAdapter | Sort-Object Name | Format-Table Name, Status, LinkSpeed, InterfaceDescription
Test-NetConnection 192.168.50.12 -Port PORT
```

## Troubleshooting

### Cannot ping another PC

Check Ethernet, IP address, subnet mask, Windows Firewall, VLAN settings and duplicate addresses.

### RPC port fails

Check that the worker process is running, the IP and port are correct, the firewall permits the connection and the server is bound to the intended interface.

### Model does not fit

Try a smaller quantization, smaller model, lower context size or a different device split.

### Slower after adding PCs

Common causes include a 1 GbE bottleneck, Wi-Fi, mixed slow/fast GPUs, poor partitioning, too much inter-node communication or thermal throttling.

## Security

- Use a private wired LAN.
- Keep Windows Firewall enabled.
- Allow only known cluster IPs.
- Do not expose llama.cpp RPC directly to the Internet.
- Keep software and GPU drivers updated.
- Verify downloaded binaries and releases.

## Folder contents

```text
3-PC-LLM-Cluster/
├── README.md
├── QUICK_START.md
├── NETWORK_DIAGRAM.svg
├── scripts/
│   ├── Check-Cluster-PC.ps1
│   └── Test-Cluster-Network.ps1
└── examples/
    ├── cluster-ip-plan.example.txt
    └── llama-cpp-rpc-command.example.bat
```

## Final recommendation

For a first three-PC lab:

```text
3 PCs
  ↓
wired Ethernet
  ↓
preferably 10 GbE
  ↓
stable IP addresses
  ↓
llama.cpp working on PC 1
  ↓
add PC 2 as RPC worker
  ↓
test
  ↓
add PC 3
  ↓
benchmark before/after
```

Do not buy GPUs or networking hardware based only on theoretical combined VRAM. First inventory the exact CPU, GPU, VRAM, RAM and network adapter in each machine.
