`ifndef UCIE_RDI_SIMPLE_SEQ_PKG_SV
`define UCIE_RDI_SIMPLE_SEQ_PKG_SV

package ucie_rdi_simple_seq_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ucie_rdi_simple_item_pkg::*;

  class ucie_rdi_simple_known_pattern_seq extends uvm_sequence #(ucie_rdi_simple_seq_item);
    `uvm_object_utils(ucie_rdi_simple_known_pattern_seq)
    int unsigned num_flits = 32;

    function new(string name = "ucie_rdi_simple_known_pattern_seq");
      super.new(name);
    endfunction

    task body();
      ucie_rdi_simple_seq_item req;
      for (int unsigned i = 0; i < num_flits; i++) begin
        req = ucie_rdi_simple_seq_item::type_id::create($sformatf("req_%0d", i));
        start_item(req);
        req.index = i;
        req.data = {64'hf17e_0000_0000_0000 | i[63:0],
                    64'ha5a5_0000_0000_0000 | (i[63:0] << 1),
                    64'h5a5a_0000_0000_0000 | (i[63:0] << 2),
                    64'hc0de_0000_0000_0000 | i[63:0]};
        finish_item(req);
      end
    endtask
  endclass
endpackage

`endif
