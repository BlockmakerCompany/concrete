# Makefile for Concrete (Modular x86_64 Architecture)

AS = nasm
LD = ld
ASFLAGS = -f elf64 -g -F dwarf
LDFLAGS =

SRC_DIR = src
OBJ_DIR = obj
BIN_DIR = bin

# 1. Object Definitions (Modules)
# Group the modules that make up the Core Agent
# Added concrete_signals.o for Graceful Shutdown
CORE_OBJS = $(OBJ_DIR)/concrete_main.o \
            $(OBJ_DIR)/concrete_env.o \
            $(OBJ_DIR)/concrete_signals.o \
            $(OBJ_DIR)/concrete_net.o \
            $(OBJ_DIR)/concrete_shm.o \
            $(OBJ_DIR)/concrete_sync.o \
            $(OBJ_DIR)/concrete_utils.o

# The Trigger (Wake-up injector)
# We also include utils.o in case the trigger needs _print_str
TRIG_OBJS = $(OBJ_DIR)/concrete_trigger.o \
            $(OBJ_DIR)/concrete_net.o \
            $(OBJ_DIR)/concrete_utils.o

# 2. Final Targets
TARGET_CORE = $(BIN_DIR)/concrete_core
TARGET_TRIG = $(BIN_DIR)/concrete_trigger

.PHONY: all clean directories

all: directories $(TARGET_CORE) $(TARGET_TRIG)

# Create directories if they do not exist
directories:
	@mkdir -p $(OBJ_DIR)
	@mkdir -p $(BIN_DIR)

# --- Linking Rules ---

$(TARGET_CORE): $(CORE_OBJS)
	$(LD) $(LDFLAGS) -o $@ $^

$(TARGET_TRIG): $(TRIG_OBJS)
	$(LD) $(LDFLAGS) -o $@ $^

# --- Generic Assembly Rule ---
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.asm
	$(AS) $(ASFLAGS) -I$(SRC_DIR)/ -o $@ $<

# Total cleanup
clean:
	rm -rf $(OBJ_DIR) $(BIN_DIR)