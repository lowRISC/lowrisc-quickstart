# See LICENSE.Cambridge for license details.
# script to burn configuration memory into the quad-SPI memory

# Xilinx Vivado script
# Version: Vivado 2018.1
# Function:
#   Download bitstream to QSPI

open_hw

connect_hw_server -url localhost:3121
set board ""
set device $::env(JTAG_PART)
puts $device
set bit $::env(JTAG_BITFILE)
foreach { target } [get_hw_targets] {
    current_hw_target $target
open_hw_target
    set devices [get_hw_devices]
    puts $device
    if { $devices == $device } {
        set board [current_hw_target]
        break
    } else {
        puts [format "%s %s" ignoring $devices]
    }
    close_hw_target
}
if { $board == "" } {
    puts "Did not find board"
    exit 1
}
current_hw_device $device
set_property PROGRAM.FILE $bit [current_hw_device]
program_hw_devices [current_hw_device]
disconnect_hw_server
