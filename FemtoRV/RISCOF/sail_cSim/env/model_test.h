#ifndef _COMPLIANCE_MODEL_H
#define _COMPLIANCE_MODEL_H

#define ALIGNMENT 2

#define RVMODEL_DATA_SECTION \
        .pushsection .tohost,"aw",@progbits;              \
        .align 8; .global tohost; tohost: .dword 0;       \
        .align 8; .global fromhost; fromhost: .dword 0;   \
        .popsection;                                      \
        .align 8; .global begin_regstate; begin_regstate: \
        .word 128;                                        \
        .align 8; .global end_regstate; end_regstate:     \
        .word 4;

//RV_COMPLIANCE_HALT
#define RVMODEL_HALT   \
  li x1, 1;            \
  write_tohost:        \
    sw x1, tohost, t5; \
    j write_tohost;

// initialize hardware platform: install default trap handler to cancel run
// [note] use ".word 0x30551073" instead of "csrrw x0, mtvec, x10" as Zicsr might not be enabled
#define RVMODEL_BOOT           \
    la    x10, boot_terminate; \
    .word 0x30551073;          \
    j     boot_end;            \
  boot_terminate:              \
    li    x10, 1;              \
    sw    x10, tohost, t5;     \
    j     boot_terminate;      \
  boot_end:

// PMP configuration
#define RVMODEL_NUM_PMPS 16
#define RVMODEL_PMP_GRAIN 0

//RV_COMPLIANCE_DATA_BEGIN
#define RVMODEL_DATA_BEGIN \
  RVMODEL_DATA_SECTION     \
  .align 4;                \
  .global begin_signature; \
  begin_signature:

//RV_COMPLIANCE_DATA_END
#define RVMODEL_DATA_END \
  .align 4;              \
  .global end_signature; \
  end_signature:

//RVTEST_IO_INIT
#define RVMODEL_IO_INIT
//RVTEST_IO_WRITE_STR
#define RVMODEL_IO_WRITE_STR(_R, _STR)
//RVTEST_IO_CHECK
#define RVMODEL_IO_CHECK()
//RVTEST_IO_ASSERT_GPR_EQ
#define RVMODEL_IO_ASSERT_GPR_EQ(_S, _R, _I)
//RVTEST_IO_ASSERT_SFPR_EQ
#define RVMODEL_IO_ASSERT_SFPR_EQ(_F, _R, _I)
//RVTEST_IO_ASSERT_DFPR_EQ
#define RVMODEL_IO_ASSERT_DFPR_EQ(_D, _R, _I)

#define RVMODEL_SET_MSW_INT

#define RVMODEL_CLEAR_MSW_INT

#define RVMODEL_CLEAR_MTIMER_INT

#define RVMODEL_CLEAR_MEXT_INT

#endif // _COMPLIANCE_MODEL_H
