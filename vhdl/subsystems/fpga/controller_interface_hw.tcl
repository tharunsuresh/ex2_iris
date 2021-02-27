# TCL File Generated by Component Editor 17.0
# Thu Aug 27 19:37:27 MDT 2020
# DO NOT MODIFY


# 
# controller_interface "controller_interface" v1.0
#  2020.08.27.19:37:27
# 
# 

# 
# request TCL package from ACDS 16.1
# 
package require -exact qsys 16.1


# 
# module controller_interface
# 
set_module_property DESCRIPTION ""
set_module_property NAME controller_interface
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME controller_interface
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL controller_interface
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file controller_interface.vhd VHDL PATH controller_interface.vhd TOP_LEVEL_FILE


# 
# parameters
# 


# 
# display items
# 


# 
# connection point clock
# 
add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock CMSIS_SVD_VARIABLES ""
set_interface_property clock SVD_ADDRESS_GROUP ""

add_interface_port clock clock clk Input 1


# 
# connection point avm
# 
add_interface avm avalon start
set_interface_property avm addressUnits SYMBOLS
set_interface_property avm associatedClock clock
set_interface_property avm associatedReset reset_n
set_interface_property avm bitsPerSymbol 8
set_interface_property avm burstOnBurstBoundariesOnly false
set_interface_property avm burstcountUnits WORDS
set_interface_property avm doStreamReads false
set_interface_property avm doStreamWrites false
set_interface_property avm holdTime 0
set_interface_property avm linewrapBursts false
set_interface_property avm maximumPendingReadTransactions 0
set_interface_property avm maximumPendingWriteTransactions 0
set_interface_property avm readLatency 0
set_interface_property avm readWaitTime 1
set_interface_property avm setupTime 0
set_interface_property avm timingUnits Cycles
set_interface_property avm writeWaitTime 0
set_interface_property avm ENABLED true
set_interface_property avm EXPORT_OF ""
set_interface_property avm PORT_NAME_MAP ""
set_interface_property avm CMSIS_SVD_VARIABLES ""
set_interface_property avm SVD_ADDRESS_GROUP ""

add_interface_port avm avm_address address Output 8
add_interface_port avm avm_read read Output 1
add_interface_port avm avm_readdata readdata Input 32
add_interface_port avm avm_write write Output 1
add_interface_port avm avm_writedata writedata Output 32


# 
# connection point avs
# 
add_interface avs avalon end
set_interface_property avs addressUnits WORDS
set_interface_property avs associatedClock clock
set_interface_property avs associatedReset reset_n
set_interface_property avs bitsPerSymbol 8
set_interface_property avs bridgedAddressOffset 0
set_interface_property avs burstOnBurstBoundariesOnly false
set_interface_property avs burstcountUnits WORDS
set_interface_property avs explicitAddressSpan 0
set_interface_property avs holdTime 0
set_interface_property avs linewrapBursts false
set_interface_property avs maximumPendingReadTransactions 0
set_interface_property avs maximumPendingWriteTransactions 0
set_interface_property avs readLatency 0
set_interface_property avs readWaitTime 1
set_interface_property avs setupTime 0
set_interface_property avs timingUnits Cycles
set_interface_property avs writeWaitTime 0
set_interface_property avs ENABLED true
set_interface_property avs EXPORT_OF ""
set_interface_property avs PORT_NAME_MAP ""
set_interface_property avs CMSIS_SVD_VARIABLES ""
set_interface_property avs SVD_ADDRESS_GROUP ""

add_interface_port avs avs_address address Input 8
add_interface_port avs avs_read read Input 1
add_interface_port avs avs_write write Input 1
add_interface_port avs avs_writedata writedata Input 32
add_interface_port avs avs_readdata readdata Output 32
set_interface_assignment avs embeddedsw.configuration.isFlash 0
set_interface_assignment avs embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment avs embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment avs embeddedsw.configuration.isPrintableDevice 0


# 
# connection point avs_irq
# 
add_interface avs_irq interrupt end
set_interface_property avs_irq associatedAddressablePoint avs
set_interface_property avs_irq associatedClock clock
set_interface_property avs_irq associatedReset reset_n
set_interface_property avs_irq bridgedReceiverOffset ""
set_interface_property avs_irq bridgesToReceiver ""
set_interface_property avs_irq ENABLED true
set_interface_property avs_irq EXPORT_OF ""
set_interface_property avs_irq PORT_NAME_MAP ""
set_interface_property avs_irq CMSIS_SVD_VARIABLES ""
set_interface_property avs_irq SVD_ADDRESS_GROUP ""

add_interface_port avs_irq avs_irq irq Output 1


# 
# connection point avm_irq
# 
add_interface avm_irq interrupt start
set_interface_property avm_irq associatedAddressablePoint avm
set_interface_property avm_irq associatedClock clock
set_interface_property avm_irq associatedReset reset_n
set_interface_property avm_irq irqScheme INDIVIDUAL_REQUESTS
set_interface_property avm_irq ENABLED true
set_interface_property avm_irq EXPORT_OF ""
set_interface_property avm_irq PORT_NAME_MAP ""
set_interface_property avm_irq CMSIS_SVD_VARIABLES ""
set_interface_property avm_irq SVD_ADDRESS_GROUP ""

add_interface_port avm_irq avm_irq irq Input 1


# 
# connection point reset_n
# 
add_interface reset_n reset end
set_interface_property reset_n associatedClock clock
set_interface_property reset_n synchronousEdges DEASSERT
set_interface_property reset_n ENABLED true
set_interface_property reset_n EXPORT_OF ""
set_interface_property reset_n PORT_NAME_MAP ""
set_interface_property reset_n CMSIS_SVD_VARIABLES ""
set_interface_property reset_n SVD_ADDRESS_GROUP ""

add_interface_port reset_n reset_n reset_n Input 1

