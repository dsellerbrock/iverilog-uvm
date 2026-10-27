// IEEE 1800 §8.27: a forward class declaration left undefined is invalid.
typedef class Missing;
class Z; Missing m; endclass
module n08_27_forward_missing;
endmodule
