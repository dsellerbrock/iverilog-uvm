// A constraint may name an element past a dynamic array's solved size when
// the constraint is vacuous in that solution, as OpenTitan kmac_smoke_vseq
// does with  if (kmac_en) fname_arr[0] == 75; ... else fname_len == 0;
// An element an active constraint needs still fails randomize().
module test;
  class c;
    rand bit en;
    rand int unsigned len;
    rand byte arr[];
    constraint k { len <= 8; arr.size() == len;
                   if (en) { len == 4; arr[0] == 75; arr[1] == 77; } else { len == 0; } }
  endclass
  class bad;
    rand int unsigned len;
    rand byte arr[];
    constraint k { len == 0; arr.size() == len; arr[2] == 5; }
  endclass
  initial begin
    automatic c o = new;
    automatic bad b = new;
    automatic int seen0 = 0, seen1 = 0, errs = 0;
    repeat (40) begin
      if (!o.randomize()) errs++;
      else if (o.en) begin if (o.arr.size() == 4 && o.arr[0] == 75 && o.arr[1] == 77) seen1++; else errs++; end
      else begin if (o.arr.size() == 0) seen0++; else errs++; end
    end
    if (errs == 0 && seen0 > 0 && seen1 > 0 && !b.randomize()) $display("PASSED");
    else $display("FAILED: %0d %0d %0d", seen0, seen1, errs);
  end
endmodule
