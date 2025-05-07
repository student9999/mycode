onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/dut/ADDR_WIDTH
add wave -noupdate /tb/dut/DATA_WIDTH
add wave -noupdate /tb/dut/BUFFER_DEPTH
add wave -noupdate /tb/dut/BEAT_BYTES
add wave -noupdate /tb/dut/BUFFER_WORDS
add wave -noupdate /tb/dut/clk
add wave -noupdate /tb/dut/rst
add wave -noupdate /tb/dut/s_axis_tdata
add wave -noupdate /tb/dut/s_axis_tvalid
add wave -noupdate /tb/dut/s_axis_tready
add wave -noupdate /tb/dut/s_axis_tlast
add wave -noupdate /tb/dut/m_axi_awaddr
add wave -noupdate /tb/dut/ddr_wr_ptr
add wave -noupdate /tb/dut/m_axi_awlen
add wave -noupdate /tb/dut/m_axi_awsize
add wave -noupdate /tb/dut/m_axi_awburst
add wave -noupdate -color Magenta /tb/dut/m_axi_awvalid
add wave -noupdate /tb/dut/m_axi_awready
add wave -noupdate /tb/dut/m_axi_wdata
add wave -noupdate /tb/dut/m_axi_wstrb
add wave -noupdate /tb/dut/m_axi_wlast
add wave -noupdate /tb/dut/m_axi_wvalid
add wave -noupdate /tb/dut/m_axi_wready
add wave -noupdate /tb/dut/m_axi_bready
add wave -noupdate /tb/dut/header_beat
add wave -noupdate /tb/dut/fifo
add wave -noupdate /tb/dut/wr_ptr
add wave -noupdate /tb/dut/rd_ptr
add wave -noupdate /tb/dut/byte_cnt
add wave -noupdate /tb/dut/fifo_full
add wave -noupdate /tb/dut/fifo_empty
add wave -noupdate /tb/dut/pkt_dropping
add wave -noupdate /tb/dut/fifo_out_d2
add wave -noupdate -divider ddr
add wave -noupdate /tb/u_ddrmc_sim/ddr_busy
add wave -noupdate /tb/u_ddrmc_sim/wr_active
add wave -noupdate /tb/u_ddrmc_sim/AWREADY
add wave -noupdate /tb/u_ddrmc_sim/AWVALID
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {206925 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 178
configure wave -valuecolwidth 117
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
WaveRestoreZoom {0 ps} {14387408 ps}
