# --- Stage 1: The Forge (Builder) ---
# Compiles the x86_64 Assembly source into stripped, static binaries.
FROM alpine:latest AS builder

# 1. Install build dependencies
RUN apk add --no-cache nasm binutils make

# 2. Setup a non-privileged user for the final execution
RUN adduser -D -u 1000 concrete_user

WORKDIR /build

# 3. Copy source and build logic
COPY Makefile ./
COPY src/ ./src/

# 4. Modular Compilation
# We build both the core and the trigger
RUN make clean && make

# 5. Binary Hardening
# Strip symbols to drop size to the absolute minimum (~10KB)
RUN strip -s bin/concrete_core bin/concrete_trigger

# --- Stage 2: The Void (Production Runner) ---
# A zero-dependency scratch image. No shell, no logs, just the processor and you.
FROM scratch

# 1. Import user identity from the Forge
COPY --from=builder /etc/passwd /etc/passwd

# 2. Deploy high-performance static binary
# We only copy the core. The trigger and scripts stay in the development layers.
COPY --from=builder /build/bin/concrete_core /app/concrete_core

WORKDIR /app
USER 1000

# Concrete Ingestion Ports
# 8080: Main UDP Ingestion
# 8081: Local IPC Trigger
EXPOSE 8080/udp
EXPOSE 8081/udp

# Execute Concrete as the entrypoint
ENTRYPOINT ["/app/concrete_core"]
