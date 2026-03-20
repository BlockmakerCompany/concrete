# 🧱 Concrete
### High-Performance Memory Synchronization Agent (Pure x86_64 Assembly)

[![Docker Image Size](https://img.shields.io/docker/image-size/blockmaker/concrete/latest)](https://hub.docker.com/r/blockmaker/concrete)
[![Docker Pulls](https://img.shields.io/docker/pulls/blockmaker/concrete)](https://hub.docker.com/r/blockmaker/concrete)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-orange.svg)](https://kernel.org)
[![Language: ASM](https://img.shields.io/badge/Language-x86__64_ASM-red.svg)](https://nasm.us)

**Concrete** is a minimalist, ultra-low latency synchronization engine designed for distributed systems. Written entirely in **x86_64 Assembly**, it bypasses the standard C library (`libc`) to interact directly with the Linux Kernel via syscalls, achieving near-zero overhead.

---

## 📑 Table of Contents
* [🎯 The Problem & Solution](#-the-problem--the-runtime-tax-in-high-frequency-systems)
* [⚡ Performance Metrics](#-performance-metrics)
* [🏗 System Architecture](#-system-architecture)
* [🛠 Technical Specifications](#-technical-specifications--protocol)
* [🚦 Getting Started](#-getting-started)
* [⚙️ Configuration](#️-configuration)
* [🧪 Testing & QA](#-testing--quality-assurance)
* [📈 Roadmap](#-roadmap--future-development)

---

## 🎯 The Problem: The "Runtime Tax" in High-Frequency Systems

In traditional ingestion stacks (e.g., Python/Node/Go + Redis), processing 500,000 packets per second introduces significant overhead:
* **Context Switching:** Constant jumping between Kernel and User space.
* **Memory Copying:** Data is copied from the NIC buffer to Kernel space, then to the Application buffer.
* **GC Pauses:** Runtimes stop execution to clean up temporary objects.

**At scale, your CPU spends 70% of its time managing the data, not processing it.**

## ⚡ The Solution: Concrete's Fast-Path Architecture

Concrete provides a **Zero-Copy Data Plane** written in x86_64 Assembly. It acts as a dedicated high-speed buffer between the network and your business logic.



### 1. The Ingestion Interface (UDP)
A sensor or a ticker-plant sends a raw UDP frame.
* **Header (8 bytes):** `CONCRETE` (Magic validation).
* **Index (8 bytes):** Target Block ID (0-63).
* **Payload (64 bytes):** Raw binary data.

### 2. The Internal Processing (Assembly Core)
The Core uses `epoll` in edge-triggered mode. When a packet arrives:
1.  **Direct Read:** `recvfrom` moves data directly into the Core's registers/stack.
2.  **Instant Validation:** Assembly `cmp` instructions validate the magic header in CPU cycles, not milliseconds.
3.  **Zero-Copy Write:** The payload is moved directly into a **Shared Memory (SHM)** segment at a calculated offset.

### 3. The Consumer Interface (Shared Memory)
Your high-level application (written in Go, C++, or Rust) maps the same SHM file. **It can read the latest data without a single network call or database query.**

```go
// Example: A Go consumer reading from Concrete SHM
file, _ := os.OpenFile("/dev/shm/concrete.data", os.O_RDONLY, 0666)
data, _ := mmap.Map(file, mmap.RDONLY, 0)

// Accessing Block 7 is just a pointer offset away
latestValue := data[7*64 : 7*64 + 64] 
```

**Result:** Your application logic stays in a high-level language, but your data ingestion happens at the speed of the processor.

---

## 🎯 Project Philosophy
In modern infrastructure, overhead is the enemy. **Concrete** was built to prove that a synchronization layer can be both robust and virtually weightless.

* **Zero Dependencies:** No interpreted languages, no runtime, no virtual machines. Just binary instructions.
* **Kernel-Native:** Utilizes `epoll` for event-driven networking and `mmap` for direct hardware-backed shared memory.
* **Safety First:** Despite being low-level, the core implements strict bounds-checking to prevent Buffer Overflows and unauthorized memory access.

---

## ⚡ Performance Metrics
Concrete is optimized for high-throughput, low-latency environments where every CPU cycle counts.

* **Runtime Footprint:** < 1MB Resident Set Size (RSS).
* **Binary Size:** ~10KB (Static executable, no `libc`).
* **Networking Complexity:** $O(1)$ event processing via `epoll_wait`.
* **Memory Sync Latency:** Microsecond-range `rep movsb` operations for 64-byte block alignment.
* **Packet Handling:** Direct-to-RAM injection. No intermediate buffers or high-level string parsing.

### 📊 Competitor Comparison (Approximate)

| Feature | Python/Node | Go/Rust (Std) | **Concrete (ASM)** |
| :--- | :--- | :--- | :--- |
| **Runtime Overhead** | High (VM/Interpreter) | Low (Runtime/GC) | **Zero (Native)** |
| **Memory Access** | Abstraction Layers | Pointers/References | **Direct Syscall/SHM** |
| **Context Switches** | Frequent | Minimal | **Optimized epoll loop** |
| **Max Throughput** | ~50k PPS | ~150k-250k PPS | **480k+ PPS** |
| **Binary Size** | >50MB (Env) | >5MB | **~10KB** |

---

## 🏗 System Architecture

### Data Flow Diagram
The following ASCII diagram illustrates the path of a synchronization packet from the network interface to the Shared Memory (SHM) segment:

```text
[ UDP Packet ] -> [ Network Card ]
|
v
[ Linux Kernel ] -> [ epoll_wait() ]
|
(Payload: 72b) <-----/
|
v
[ Concrete Core ]
|
|-- 1. Validate Size (72 bytes)
|-- 2. Extract Block ID (8 bytes)
|-- 3. Calculate Offset (ID << 6)
|-- 4. Execute `rep movsb` (64 bytes)
|
v
[ /dev/shm/concrete.data ] <--- [ Other Microservices ]
```

---

## 🛠 Technical Specifications & Protocol

### The 72-Byte Sync Packet
Every incoming UDP packet must follow this exact structure. Any variation results in an immediate packet drop.

| Offset | Field | Size | Description |
| :--- | :--- | :--- | :--- |
| **00** | **Block ID** | 8 Bytes | 64-bit Integer (Little-endian). Range: 0-63. |
| **08** | **Payload** | 64 Bytes | Raw data to be synchronized into the target block. |

### Memory Layout
The Shared Memory region is a fixed 4KB slab, perfectly aligned for CPU cache efficiency.

```text
0x0000 [ Block 0 (64 bytes)  ]
0x0040 [ Block 1 (64 bytes)  ]
...
0x01C0 [ Block 7 (64 bytes)  ] <-- Example Test Offset
...
0x0FC0 [ Block 63 (64 bytes) ]
```

### 📟 The Syscall Stack
Concrete bypasses `libc` and talks directly to the CPU using:
* `sys_socket` & `sys_bind`: Socket initialization.
* `sys_epoll_create1` & `sys_epoll_ctl`: Event notification setup.
* `sys_epoll_wait`: The high-frequency event loop.
* `sys_recvfrom`: Zero-copy network ingestion.
* `sys_mmap`: Shared memory mapping.
* `sys_write`: Minimalist logging to `stdout`.

---

## 🚀 Quick Start (Pre-built Image)

If you don't want to build from source, you can pull the official hardened image directly from **Docker Hub**:

```bash
# Pull the ultra-minimalist (scratch-based) image
docker pull blockmaker/concrete:latest

# Run the core agent (Map your local /dev/shm for direct access)
docker run -d \
  --name concrete-core \
  -p 8080:8080/udp \
  --ipc="shareable" \
  blockmaker/concrete:latest
```

---

## 🚦 Getting Started

### Prerequisites
* **Linux Environment** (Kernel 4.x+)
* **Docker & Docker Compose**
* **NASM & Binutils** (For native builds)

### 1. Orchestrated Deployment & Test
The fastest way to verify Concrete is using the automated test suite. This compiles the source, spins up the Core, and executes a native trigger to verify memory integrity.

```bash
docker compose up --build --abort-on-container-exit --exit-code-from tester
```

### 2. Native Build
To build the binaries directly on your Linux host:

```bash
# Build binaries in /bin
make clean && make

# Start the synchronization agent
./bin/concrete_core
```

### 3. Manual Memory Injection
Use the included `concrete_trigger` utility to manually sync data:

```bash
# Usage: ./bin/concrete_trigger <ID> "<MESSAGE>"
./bin/concrete_trigger 7 "PROT_V2_ACTIVE"
```

---

## ⚙️ Configuration

Concrete is highly customizable through Environment Variables. This makes it a perfect fit for Docker and Kubernetes deployments.

| Variable | Default | Description |
| :--- | :--- | :--- |
| `CONCRETE_PORT` | `8080` | The base UDP port. The Agent listens for cluster syncs on this port, and opens `PORT + 1` (e.g., 8081) for local IPC triggers. |
| `CONCRETE_SHM` | `/dev/shm/concrete.data` | The absolute path to the POSIX Shared Memory file. |
| `CONCRETE_LOG` | `1` | Verbosity level. `0` = Silent (Max Performance), `1` = Info (Startup/Shutdown), `2` = Debug (Trace every delta/merge). |

### Example `docker-compose.yml` snippet:

```yaml
services:
  concrete:
    build: .
    environment:
      - CONCRETE_PORT=8080
      - CONCRETE_LOG=2
```

---

## 🧪 Testing & Quality Assurance

Concrete includes a comprehensive suite to ensure protocol integrity, memory safety, and high-frequency stability.

### 1. Environment Preparation
Before running native tests, initialize the Shared Memory segment to ensure correct permissions and size:
```bash
sh scripts/setup_shm.sh
```

### 2. Functional Validation
The functional suite verifies block alignment, data persistence, and boundary conditions (ID 0 to 63).
```bash
# Run via Docker Compose (Recommended for isolated validation)
docker-compose up tester

# Or run natively (Requires core running in background)
sh scripts/test_functional.sh
```

### 3. Security Audit (Protocol Fuzzing)
This test spawns an isolated Docker container and attacks the UDP socket with malformed, truncated, and out-of-bounds packets to verify the x86_64 Core's resilience.
```bash
sh scripts/security_fuzz.sh
```

### 4. High-Frequency Benchmarking
To measure the true throughput of the Assembly engine without Bash overhead, we use a high-concurrency Go stresser.

**Performance Metrics:**
* **Throughput:** ~390,000 - 480,000 PPS (Packets Per Second).
* **Latency:** Sub-3 microseconds internal processing.
* **Zero-Copy:** Direct Kernel-to-SHM data flow.

**Execution:**
1. Ensure the core is running: `./bin/concrete_core &`
2. Launch the stress test:
```bash
go run scripts/bench.go
```
3. Inspect the results in RAM:
```bash
hexdump -C /dev/shm/concrete.data | head -n 20
```

---

## 🛠️ Project Structure
* `src/`: x86_64 Assembly source code.
* `bin/`: Compiled ELF64 binaries.
* `scripts/setup_shm.sh`: Environment and permission initializer.
* `scripts/test_functional.sh`: Logic and boundary validation.
* `scripts/security_fuzz.sh`: Docker-based vulnerability audit.
* `scripts/bench.go`: High-performance Go-based stresser.

---

## 📈 Roadmap & Future Development
- [ ] **Multi-Node Replication:** Forwarding packets to cluster peers.
- [ ] **AES-NI Encryption:** On-the-fly decryption of payloads using hardware instructions.
- [ ] **Prometheus Exporter:** A sidecar in ASM to export sync metrics via HTTP.
- [ ] **Lock-Free Queue:** Implementing a ring buffer for high-burst handling.

---

## 📜 License
This project is licensed under the **MIT License**. See the `LICENSE` file for details.

---

## 🏢 Backed by BlockMaker S.R.L.

**Concrete** was engineered from scratch by the engineering team at **BlockMaker S.R.L.**, led by **Fernando Ezequiel Mancuso** (Head of Engineering).

At BlockMaker, we believe in deep tech, zero-dependency architectures, and pushing the absolute limits of hardware efficiency. We are actively encouraging the global engineering community to fork, benchmark, and contribute to this project.

If you love low-level systems engineering and uncompromising performance, feel free to reach out at [fernando.mancuso@blockmaker.net](mailto:fernando.mancuso@blockmaker.net).
