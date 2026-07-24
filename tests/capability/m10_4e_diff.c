extern int sv_a(int); extern int sv_b(int);
int c_a(int d){ sv_a(d); return 0; }
int c_b(int d){ sv_b(d); return 0; }
