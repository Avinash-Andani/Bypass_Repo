import struct

BIN_FILE = "firmware.bin"
HEX_FILE = "firmware.hex"
TOTAL_WORDS = 1024
NOP_INSTRUCTION = 0x00000013  # RISC-V ADDI x0, x0, 0

with open(BIN_FILE, "rb") as f:
    raw = f.read()

while len(raw) % 4 != 0:
    raw += b"\x00"

num_words = len(raw) // 4
words = list(struct.unpack(f"<{num_words}I", raw))

if len(words) > TOTAL_WORDS:
    raise ValueError(f"Firmware size ({len(words)} words) exceeds 1024-word BRAM!")

while len(words) < TOTAL_WORDS:
    words.append(NOP_INSTRUCTION)

with open(HEX_FILE, "w") as f:
    for w in words:
        f.write(f"{w:08x}\n")

print(f"Successfully generated {HEX_FILE}: {num_words} code words + {TOTAL_WORDS - num_words} NOP words.")
