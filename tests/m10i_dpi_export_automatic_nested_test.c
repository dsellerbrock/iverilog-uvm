/* M10-4 follow-on: C side. An imported *task* so the exported task it
 * calls has a coroutine to park on while it consumes time. */
extern int sv_outer(int, int);

int c_go(int d, int id)
{
      return sv_outer(d, id);
}
