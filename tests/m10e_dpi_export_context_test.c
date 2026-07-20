/* DPI companion for m10e_dpi_export_context_test: an imported "context"
 * function calls the exported m10e_localf WITHOUT svSetScope, relying on
 * the 35.5.2 context default (the export runs in the import's instance).
 * The vvp runtime resolves the instance from the active DPI scope (the
 * import's own scope, whose enclosing instance is the caller's). */
extern int m10e_localf(int a);

int m10e_ctx(void)
{
      return m10e_localf(1);
}
