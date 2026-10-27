/* Save an m68k task context directly on its own user stack. */

#include "aros/m68k/asm.h"

        .text
        .balign 4
        .globl  AROS_SLIB_ENTRY(Switch,Exec,9)
        .globl  m68k_VoluntarySwitch

        .func AROS_SLIB_ENTRY(Switch,Exec,9)
AROS_SLIB_ENTRY(Switch,Exec,9):
        move.w  #0x2000,%sr

        /*
         * Keep the caller's A5 temporarily on the supervisor stack.  Build
         * the persistent frame on the user stack in the Kickstart layout:
         * PC(4), SR(2), D0-D7/A0-A6(60).  The original USP is frame + 66.
         */
        move.l  %a5,%sp@-
        move.l  %usp,%a5
        movem.l %d0-%d7/%a0-%a6,%a5@-
        move.l  %sp@+,%a5@(13*4)
        move.w  %sp@+,%a5@-
        move.l  %sp@+,%a5@-

        /*
         * A task that is in supervisor mode (it called SuperState()) runs on
         * its own supervisor stack. That stack pointer is not part of the
         * frame above and the SSP register is shared by all tasks, so it
         * has to be remembered, or the task would resume on whatever stack
         * pointer the last task left. After the SR and PC were popped, only
         * the format word of the exception frame (68010 and up) is left on
         * the supervisor stack; the task's own stack pointer was just above
         * it. A6 is not necessarily SysBase here, use AbsExecBase.
         */
        sub.l   %a0,%a0
        btst    #5,%a5@(4)              /* saved SR: supervisor mode? */
        beq.s   1f
        move.l  %sp,%a0
        move.l  4,%a1
        btst    #0,%a1@(AttnFlags+1)    /* 68010 or better: format word */
        beq.s   1f
        addq.l  #2,%a0
1:
        move.l  %a0,%sp@-               /* ssp */
        move.l  %a5,%sp@-               /* frame */
        jsr     m68k_SwitchTail
        addq.l  #8,%sp
        jmp     __Dispatch_this
        .endfunc

        /*
         * KrnSwitch() is used only by Exec/Wait(), after Wait has linked the
         * current task into TaskWait.  Keep this entry distinct from the
         * general Switch vector: no scheduler-policy call is required for
         * the outgoing task, and Paula interrupts can be reopened as soon as
         * its persistent frame and nesting state have been published.
         */
        .func m68k_VoluntarySwitch
m68k_VoluntarySwitch:
        move.w  #0x2000,%sr
        move.l  %a5,%sp@-
        move.l  %usp,%a5
        movem.l %d0-%d7/%a0-%a6,%a5@-
        move.l  %sp@+,%a5@(13*4)
        move.w  %sp@+,%a5@-
        move.l  %sp@+,%a5@-

        /*
         * Remember the supervisor stack pointer of a task that waits in
         * supervisor mode, see Switch() above. This runs before the
         * critical section; if a signal arrives and the task does not switch,
         * the record is simply never used (it is tied to this frame).
         */
        sub.l   %a0,%a0
        btst    #5,%a5@(4)
        beq.s   2f
        move.l  %sp,%a0
        btst    #0,%a6@(AttnFlags+1)
        beq.s   2f
        addq.l  #2,%a0
2:
        move.l  %a5,%sp@-               /* frame */
        move.l  %a0,%sp@-               /* ssp */
        jsr     m68k_SaveSSP
        addq.l  #8,%sp

        /*
         * The expensive trap and context save above run with interrupts
         * enabled.  Only the signal recheck and scheduler-list commit below
         * form the critical section.
         */
        move.w  #0x4000,0xdff09a
        move.l  ThisTask(%a6),%a0
        move.b  %d3,%d1
        addq.b  #1,%d1
        move.b  %d1,IDNestCnt(%a6)

        move.l  tc_SigRecvd(%a0),%d0
        and.l   tc_SigWait(%a0),%d0
        bne.s   1f

        move.b  #-1,TDNestCnt(%a6)
        move.b  #4,tc_State(%a0)       /* TS_WAIT */

        /* AddTail(&SysBase->TaskWait, &task->tc_Node). */
        lea.l   TaskWait(%a6),%a1
        move.l  lh_TailPred(%a1),%a2
        lea.l   ln_Pred(%a1),%a3
        move.l  %a3,ln_Succ(%a0)
        move.l  %a2,ln_Pred(%a0)
        move.l  %a0,ln_Succ(%a2)
        move.l  %a0,lh_TailPred(%a1)

        move.l  %a5,tc_SPReg(%a0)
        move.b  %d1,tc_IDNestCnt(%a0)
        move.b  #-1,IDNestCnt(%a6)
        move.w  #0xc000,0xdff09a
        jmp     __Dispatch_this

1:
        /*
         * A signal arrived while the prospective frame was being built.
         * Recreate Supervisor()'s exception frame, restore the registers
         * from that frame, and return to Wait() without switching tasks.
         */
        move.l  %a5@,%sp@-
        move.w  %a5@(4),%sp@-
        movem.l %a5@(6),%d0-%d7/%a0-%a6
        rte
        .endfunc
