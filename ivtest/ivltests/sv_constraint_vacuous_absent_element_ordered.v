// The ordered-solve form of sv_constraint_vacuous_absent_element: with
// `solve ... before arr', element references are bound in a second pass
// after the sizes are solved. OpenTitan kmac_smoke_vseq's legal_fname_c.
module test;
  typedef enum bit [1:0] { ErrNone, ErrName, ErrOther } err_e;
  class c;
    rand err_e err;
    rand bit en;
    rand int unsigned len;
    rand byte arr[];
    constraint sz { len <= 8; arr.size() == len; }
    constraint k {
      solve err before en;
      solve err before arr;
      if (err != ErrName) {
        if (en) { len == 4; arr[0] == 75; arr[1] == 77; arr[2] == 65; arr[3] == 67; }
        else { len == 0; }
      }
    }
    constraint chars { foreach (arr[i]) arr[i] inside {32, [65:90], [97:122]}; }
  endclass
  class bad;
    rand bit en;
    rand int unsigned len;
    rand byte arr[];
    constraint k { solve en before arr; arr.size() == len; len == 0; arr[1] == 3; }
  endclass
  initial begin
    automatic c o = new;
    automatic bad b = new;
    automatic int seen0 = 0, seen1 = 0, errs = 0;
    repeat (60) begin
      if (!o.randomize()) errs++;
      else if (o.err != ErrName && o.en) begin
        if (o.arr.size() == 4 && o.arr[0] == 75 && o.arr[3] == 67) seen1++; else errs++;
      end else if (o.err != ErrName) begin
        if (o.arr.size() == 0) seen0++; else errs++;
      end
    end
    if (errs == 0 && seen0 > 0 && seen1 > 0 && !b.randomize()) $display("PASSED");
    else $display("FAILED: %0d %0d %0d", seen0, seen1, errs);
  end
endmodule
