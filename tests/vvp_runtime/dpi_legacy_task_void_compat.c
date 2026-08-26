#include <stdio.h>

/* This intentionally uses the pre-task-ack VVP implementation ABI. The raw
 * image uses the retained legacy %dpi/call/task opcode, so a new runtime must
 * not reinterpret this function as returning an acknowledgement int. */
void dpi_legacy_void_task(void)
{
    puts("legacy void DPI task called");
    puts("PASS legacy DPI task void ABI compatibility");
}
