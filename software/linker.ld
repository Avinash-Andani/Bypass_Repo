OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
  BRAM (rwx) : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS
{
  .text : {
    *(.text.init)
    *(.text*)
  } > BRAM

  .rodata : {
    *(.rodata*)
  } > BRAM

  .data : {
    *(.data*)
  } > BRAM

  .bss : {
    *(.bss*)
    *(COMMON)
  } > BRAM
}
