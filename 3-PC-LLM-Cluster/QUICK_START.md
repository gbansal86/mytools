# Quick Start — Three PCs, One LLM

## 1. Connect the PCs

```text
PC 1 ──┐
PC 2 ──┼── Ethernet switch
PC 3 ──┘
```

Prefer wired 10 GbE if you intend to split a model across machines.

## 2. Give each PC a stable address

```text
PC 1  192.168.50.11
PC 2  192.168.50.12
PC 3  192.168.50.13
```

## 3. Verify connectivity

From PC 1:

```bat
ping 192.168.50.12
ping 192.168.50.13
```

## 4. Inventory every machine

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Check-Cluster-PC.ps1
```

## 5. Prove the model works on PC 1 first

Run the GGUF model locally with llama.cpp before adding remote workers.

## 6. Enable llama.cpp RPC

Follow the current official guide:

https://github.com/ggml-org/llama.cpp/blob/master/tools/rpc/README.md

## 7. Start PC 2 as an RPC worker

Keep the RPC service on the private LAN only.

## 8. Verify its TCP port

```powershell
Test-NetConnection 192.168.50.12 -Port PORT
```

## 9. Add PC 2 to PC 1

Concept:

```bat
llama-server -m D:\Models\model.gguf -ngl 99 --rpc 192.168.50.12:PORT
```

## 10. Add PC 3

Once two PCs work:

```bat
llama-server -m D:\Models\model.gguf -ngl 99 --rpc 192.168.50.12:PORT,192.168.50.13:PORT
```

Use the current upstream documentation for the supported executable names, ports and arguments.

## 11. Benchmark

Compare:

- PC 1 alone
- PC 1 + PC 2
- PC 1 + PC 2 + PC 3

More computers can make a larger model possible, but they do not guarantee linear speed gains.
