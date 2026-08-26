/* Deliberate IEEE 1800-2017/2023 35.9(d) violation. Acknowledgement does not
 * clear disabled state, so the second export remains illegal. */
#include "svdpi.h"

extern void dpi_disable_export_parent(void);
extern int dpi_forbidden_export(void);

void dpi_bad_export_after_disable(void)
{
    dpi_disable_export_parent();
    svAckDisabledState();
    (void)dpi_forbidden_export();
}
