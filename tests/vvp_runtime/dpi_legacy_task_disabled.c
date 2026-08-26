/* Historical imported-task implementation ABI: deliberately void. */
extern int dpi_legacy_wait(void);

void dpi_legacy_disabled_task(void)
{
    (void)dpi_legacy_wait();
}
