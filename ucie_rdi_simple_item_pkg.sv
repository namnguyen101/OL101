`ifndef UCIE_RDI_SIMPLE_ITEM_PKG_SV
`define UCIE_RDI_SIMPLE_ITEM_PKG_SV

package ucie_rdi_simple_item_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class ucie_rdi_simple_seq_item extends uvm_sequence_item;
    rand bit [255:0] data;
    int unsigned index;

    `uvm_object_utils_begin(ucie_rdi_simple_seq_item)
      `uvm_field_int(data, UVM_DEFAULT)
      `uvm_field_int(index, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "ucie_rdi_simple_seq_item");
      super.new(name);
    endfunction
  endclass
endpackage

`endif
