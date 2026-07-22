// A class property whose type is a TYPE PARAMETER bound to an aggregate
// (queue / dynamic array / associative array) must be usable through its
// built-in methods, not just through indexing (IEEE 1800-2017 6.20.3 type
// parameters, 7.10/7.9/7.8 aggregate methods).
//
// Regression: the method-target elaboration path resolved the property with
// property_idx_from_name(), which returned -1 when the specialization's
// property had not yet been committed (it is elaborated on demand). The call
// was then mis-dropped as an "unknown task" and the aggregate silently stayed
// empty. Fixed by forcing ensure_property_decl() on the specialized class
// first, matching the expression/index path.

typedef int int_q_t[$];
typedef int int_da_t[];
typedef int int_aa_t[string];

class box #(type T = int);
  T value;
endclass

module sv_typeparm_aggregate_property;
  box#(int_q_t)  bq;
  box#(int_da_t) bd;
  box#(int_aa_t) ba;
  int errors = 0;

  initial begin
    // Queue methods through a type-parameter property.
    bq = new;
    bq.value.push_back(7);
    bq.value.push_back(9);
    bq.value.push_front(3);
    if (bq.value.size() != 3) begin $display("FAILED queue size=%0d exp=3", bq.value.size()); errors++; end
    if (bq.value[0]  != 3) begin $display("FAILED queue[0]=%0d exp=3", bq.value[0]); errors++; end
    if (bq.value[2]  != 9) begin $display("FAILED queue[2]=%0d exp=9", bq.value[2]); errors++; end

    // Dynamic-array methods through a type-parameter property.
    bd = new;
    bd.value = new[3];
    bd.value[1] = 42;
    if (bd.value.size() != 3) begin $display("FAILED darray size=%0d exp=3", bd.value.size()); errors++; end
    if (bd.value[1]  != 42) begin $display("FAILED darray[1]=%0d exp=42", bd.value[1]); errors++; end

    // Associative-array methods through a type-parameter property.
    ba = new;
    ba.value["k"] = 5;
    ba.value["m"] = 6;
    if (ba.value.num()      != 2) begin $display("FAILED assoc num=%0d exp=2", ba.value.num()); errors++; end
    if (!ba.value.exists("k"))    begin $display("FAILED assoc exists(k)"); errors++; end
    if (ba.value["m"]       != 6) begin $display("FAILED assoc[m]=%0d exp=6", ba.value["m"]); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
