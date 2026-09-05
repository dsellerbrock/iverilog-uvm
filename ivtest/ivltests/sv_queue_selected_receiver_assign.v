// IEEE 1800-2017/2023 7.10.1: the first index selects the receiver,
// and writing beyond a queue's $+1 must warn and leave it unchanged.
class row;
  int entries[$];
endclass
module main;
  typedef struct { int entries[$]; } record_t;
  record_t records[$];
  row handles[$];
  row a, b;
  initial begin
    records = '{'{'{1}}, '{'{2}}};
    records[1].entries = '{10, 20};
    if (records[0].entries.size() != 1 || records[0].entries[0] != 1 ||
        records[1].entries.size() != 2 || records[1].entries[1] != 20)
      $fatal(1, "receiver index reused as property index");
    a = new; b = new;
    handles.push_back(a); handles.push_back(b);
    handles[1].entries = '{30, 40};
    if (a.entries.size() != 0 || b.entries.size() != 2 || b.entries[1] != 40)
      $fatal(1, "class receiver queue assignment failed");
    handles[7] = a;
    if (handles.size() != 2 || handles[1] != b)
      $fatal(1, "invalid write grew or changed object queue");
    $display("PASSED");
  end
endmodule
