@echo off
REM ============================================================================
REM EXAMPLE ONLY - LLAMA.CPP DISTRIBUTED RPC COMMAND
REM ============================================================================
REM Read the current documentation before running:
REM https://github.com/ggml-org/llama.cpp/blob/master/tools/rpc/README.md
REM
REM Replace the model path, worker IPs and RPC port with your real values.
REM Keep RPC on a trusted private LAN only.
REM ============================================================================

set MODEL=D:\Models\YOUR_MODEL.gguf
set PC2=192.168.50.12
set PC3=192.168.50.13
set RPC_PORT=REPLACE_ME

echo.
echo Example command:
echo llama-server -m "%MODEL%" -ngl 99 --rpc %PC2%:%RPC_PORT%,%PC3%:%RPC_PORT%
echo.
echo Check the current upstream RPC README before running.
pause
