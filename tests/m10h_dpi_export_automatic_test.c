/* M10-4: C side of the automatic-lifetime DPI export test.
 *
 * Both imports are thin -- the point of the test is what the SV side sees
 * in its formal arguments, so these just forward and return. c_call_task
 * is an imported *task* so that a time-consuming exported task has a
 * coroutine to park on. */
extern int sv_auto_fn(int);
extern int sv_auto_task(int, int);

int c_call_fn(int v)
{
      return sv_auto_fn(v);
}

int c_call_task(int d, int id)
{
      return sv_auto_task(d, id);
}
