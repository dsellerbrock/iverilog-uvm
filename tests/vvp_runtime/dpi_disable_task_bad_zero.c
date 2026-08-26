/* Deliberate IEEE 1800-2017/2023 35.9(b) violation: the enclosing import is
 * disabled while dpi_wait_for_disable is active, but this task reports 0. */
extern int dpi_wait_for_disable(void);

int dpi_bad_disabled_task(void)
{
    (void)dpi_wait_for_disable();
    return 0;
}
