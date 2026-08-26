/* Deliberate IEEE 1800-2017/2023 35.9(c) violation. The exported function
 * disables the parent of this import, but this function omits the required
 * svAckDisabledState() call. */
extern void dpi_disable_unacked_parent(void);

void dpi_bad_unacked_function(void)
{
    dpi_disable_unacked_parent();
}
