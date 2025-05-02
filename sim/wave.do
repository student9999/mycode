onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_mrmac_2_ddr/dut/ADDR_WIDTH
add wave -noupdate /tb_mrmac_2_ddr/dut/DATA_WIDTH
add wave -noupdate /tb_mrmac_2_ddr/dut/ID_WIDTH
add wave -noupdate /tb_mrmac_2_ddr/dut/BUFFER_DEPTH
add wave -noupdate /tb_mrmac_2_ddr/dut/BEAT_BYTES
add wave -noupdate /tb_mrmac_2_ddr/dut/BUFFER_WORDS
add wave -noupdate /tb_mrmac_2_ddr/dut/SIZE_CODE
add wave -noupdate /tb_mrmac_2_ddr/dut/clk
add wave -noupdate /tb_mrmac_2_ddr/dut/rst
add wave -noupdate /tb_mrmac_2_ddr/dut/s_axis_tdata
add wave -noupdate /tb_mrmac_2_ddr/dut/s_axis_tvalid
add wave -noupdate /tb_mrmac_2_ddr/dut/s_axis_tready
add wave -noupdate /tb_mrmac_2_ddr/dut/s_axis_tlast
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_awid
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_awaddr
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_awlen
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_awsize
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_awburst
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_awvalid
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_awready
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_wdata
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_wstrb
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_wlast
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_wvalid
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_wready
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_bid
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_bresp
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_bvalid
add wave -noupdate /tb_mrmac_2_ddr/dut/m_axi_bready
add wave -noupdate /tb_mrmac_2_ddr/dut/fifo
add wave -noupdate /tb_mrmac_2_ddr/dut/wr_ptr
add wave -noupdate /tb_mrmac_2_ddr/dut/rd_ptr
add wave -noupdate /tb_mrmac_2_ddr/dut/byte_cnt
add wave -noupdate /tb_mrmac_2_ddr/dut/addr
add wave -noupdate /tb_mrmac_2_ddr/dut/total_length
add wave -noupdate /tb_mrmac_2_ddr/dut/fifo_full
add wave -noupdate /tb_mrmac_2_ddr/dut/fifo_empty
add wave -noupdate -expand /tb_mrmac_2_ddr/dut/wvalid_hold
add wave -noupdate /tb_mrmac_2_ddr/dut/pkt_dropping
add wave -noupdate /tb_mrmac_2_ddr/dut/fifo_out_d2
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {152889 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 219
configure wave -valuecolwidth 343
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {397680 ps}
