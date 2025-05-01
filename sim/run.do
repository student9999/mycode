vlog ../*.sv
vsim -voptargs=+acc work.axis_ipv4_to_axi4_writer_tb
log -r /*
do wave.do