// IEEE 1800-2017/2023 18.4.2,18.6.3; 2017 18.5.8.1/2023 18.5.7.1.
class child;
  randc bit [1:0] data[];
  bit reject;
  constraint c { data.size()==2; foreach(data[i]) { data[i] <= 3; !reject; } }
endclass
class root;
  rand child c;
  function new(); c = new; endfunction
endclass
class queue_child;
  randc bit [1:0] data[$];
  function new(); data.push_back(0); endfunction
endclass
class queue_root;
  rand queue_child c;
  function new(); c = new; endfunction
endclass
class sized_queue_child;
  randc bit [1:0] data[$];
  constraint c { data.size()==1; }
endclass
class sized_queue_root;
  rand sized_queue_child c;
  function new(); c = new; endfunction
endclass
module main;
  root r = new;
  queue_root q = new;
  sized_queue_root sq = new;
  bit [3:0] seen0, seen1, queue_seen, sized_queue_seen;
  bit [1:0] before0, before1;
  initial begin
    r.srandom(43); r.c.srandom(47);
    repeat (12) begin
      seen0=0; seen1=0; queue_seen=0; sized_queue_seen=0;
      repeat (4) begin
        if (!r.randomize()) $fatal(1, "fixed-size randc solve failed");
        if (seen0[r.c.data[0]] || seen1[r.c.data[1]]) $fatal(1, "deferred fill left ghost history");
        seen0[r.c.data[0]]=1; seen1[r.c.data[1]]=1;
        before0=r.c.data[0]; before1=r.c.data[1]; r.c.reject=1;
        if (r.randomize() || r.c.data.size()!=2 || r.c.data[0]!=before0 || r.c.data[1]!=before1)
          $fatal(1, "failed element pass did not roll back");
        r.c.reject=0;
        if (!q.randomize() || queue_seen[q.c.data[0]])
          $fatal(1, "narrow live queue rejected or repeated");
        queue_seen[q.c.data[0]]=1;
        if (!sq.randomize() || sq.c.data.size()!=1 || sized_queue_seen[sq.c.data[0]])
          $fatal(1, "sized queue rejected or repeated");
        sized_queue_seen[sq.c.data[0]]=1;
      end
      if (seen0!=15 || seen1!=15 || queue_seen!=15 || sized_queue_seen!=15) $fatal(1, "incomplete container cycles");
    end
    $display("PASSED");
  end
endmodule
