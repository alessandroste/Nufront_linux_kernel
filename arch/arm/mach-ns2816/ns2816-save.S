/*
 * arch/arm/mach-ns2816/sleep.S
 *
 * CPU state save & restore routines for CPU hotplug
 *
 * Copyright (c) 2010, Nufront Corporation.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#include "suspend-macro.S"
#include "scm.h"

/*suspend to ram debug for realview debugger*/
/*#define DEBUG_STR_MODE*/

/*      .section ".cpuinit.text", "ax"*/

#define TTB_FLAGS 0x6A @ IRGN_WBWA, OC_RGN_WBWA, S, NOS

#define	GPIO_DR_OFFSET		0x0
#define	GPIO_DDR_OFFSET		0x4
#define	GPIO_CTL_OFFSET		0x8
#define INT_ARM2EC_STAT     0x4

#define I2C_ENABLE_OFFSET   		0x6C
#define I2C_SAR_OFFSET      		0x08
#define I2C_CON_OFFSET				0x0
#define I2C_DATA_CMD_OFFSET 		0x10
#define I2C_RAWINT_STAT_OFFSET		0x34
#define I2C_CLR_INT_OFFSET			0x40
#define I2C_CLR_TX_OVER_OFFSET		0x4C
#define I2C_CLR_RD_REQ_OFFSET		0x50
#define I2C_CLR_TX_ABRT_OFFSET		0x54
#define I2C_CLR_RD_DONE_OFFSET		0x58
#define I2C_CLR_ACTIVITY_OFFSET		0x5C
#define I2C_CLR_STOP_DET_OFFSET		0x60
#define I2C_CLR_START_DET_OFFSET	0x64
#define I2C_STOP_DET_BIT_SHIFT      9
#define I2C_START_DET_BIT_SHIFT		10
#define I2C_INT_SEND_READY_SHIFT	5
#define I2C_SLAVE_STAT				0x50
#define CTX_DIAGNOSTIC			40

#define DDR_CCR_OFFSET      		0x0
#define DDR_DCR_OFFSET      		0x04
#define DDR_DCR_RNKALL_BIT	 	(0x1<<13)
#define DDR_CMD_EXEC_BIT		(0x1<<31)
#define DDR_DCR_CMD_OFFSET		27
#define DDR_DCR_CMD_BITS_MASK		(0xf<<DDR_DCR_CMD_OFFSET)
#define DDR_CMD_SELF_REFRESH		(0x02<<DDR_DCR_CMD_OFFSET)
#define DDR_CMD_PRECHARGE_ALL		(0x05<<DDR_DCR_CMD_OFFSET)

#define DDR_CCR_HOST_EN_BIT		(1<<2)
#define DDR_CCR_FLUSH_BIT		(1<<27)


#define SCM_SYS_STAT_OFFSET			0x40
#define SCM_DATA_RSENT_OFFSET			0x44
#define SCM_DATA_CTX_OFFSET			0x48

#define DRAM_SAVE_ADDR0				0xBFF80000
#define DRAM_SAVE_ADDR1				0xBFF90000
#define CONTEXT_SIZE_BYTES_SHIFT		0xa

.macro	ctx_ptr, rd, tmp
	cpu_id	\tmp
	mov32	\rd, ns2816_context_area
	ldr	\rd, [\rd]
	add	\rd, \rd, \tmp, lsl #(CONTEXT_SIZE_BYTES_SHIFT)
.endm

.macro	translate, pa, va, tmp
	mov	\tmp, #0x1000
	sub	\tmp, \tmp, #1
	bic	\pa, \va, \tmp
	mcr	p15, 0, \pa, c7, c8, 1
	mrc	p15, 0, \pa, c7, c4, 0
	bic	\pa, \pa, \tmp
	and	\tmp, \va, \tmp
	orr	\pa, \pa, \tmp
.endm

/*
 *	__cortex_a9_save(int mode)
 *
 *	 spools out the volatile processor state to memory, so that
 *	 the CPU may be safely powered down. does not preserve:
 *	 - CP15 c0 registers (except cache size select 2,c0/c0,0)
 *	 - CP15 c1 secure registers (c1/c1, 0-3)
 *	 - CP15 c5 fault status registers (c5/c0 0&1, c5/c1 0&1)
 *	 - CP15 c6 fault address registers (c6/c0 0&2)
 *	 - CP15 c9 performance monitor registers (c9/c12 0-5,
 *	     c9/c13 0-2, c9/c14 0-2)
 *	 - CP15 c10 TLB lockdown register (c10/c0, 0)
 *	 - CP15 c12 MVBAR (c12/c0, 1)
 *	 - CP15 c15 TLB lockdown registers
 */
	.align L1_CACHE_SHIFT
ENTRY(__cortex_a9_save)
	mrs	r3, cpsr
	cps	0x13			@ save off svc registers
	mov	r1, sp
	stmfd	sp!, {r3-r12, lr}

	bic	r2, sp, #(L1_CACHE_BYTES-1)

1:	mcr	p15, 0, r2, c7, c14, 1	@ clean out dirty stack cachelines
	add	r2, r2, #L1_CACHE_BYTES
	cmp	r2, r1
	ble	1b
	dsb
	/* r0 = mode */
	ctx_ptr	r8, r9
	mov	r12, r0

	/* zero-out context area */
	mov	r9, r8
	add	r10, r8, #(CONTEXT_SIZE_WORDS)
	mov	r0, #0
	mov	r1, #0
	mov	r2, #0
	mov	r3, #0
	mov	r4, #0
	mov	r5, #0
	mov	r6, #0
	mov	r7, #0
2:	stmia	r9!, {r0-r7}
	cmp	r9, r10
	blo	2b

	mov	r0, sp
	mov	sp, r12			@ sp holds the power mode
	mrs	r1, cpsr
	mrs	r2, spsr

	mrc	p15, 0, r3, c1, c0, 2	@ cpacr  coprocessor access register
	stmia	r8, {r0-r3}
	mrc	p15, 2, r0, c0, c0, 0	@ csselr  cache size sel register
	mrc	p15, 0, r1, c1, c0, 0	@ sctlr   system control register
	mrc	p15, 0, r2, c1, c0, 1	@ actlr  auxiliary control register
	mrc	p15, 0, r4, c15, c0, 0	@ pctlr  power control register
	add	r9, r8, #CTX_CSSELR
	stmia	r9, {r0-r2, r4}

#ifdef CONFIG_VFPv3
	orr	r2, r3, #0xF00000
	mcr	p15, 0, r2, c1, c0, 2	@ enable access to FPU
	VFPFMRX	r2, FPEXC
	str	r2, [r8, #CTX_FPEXC]
	mov	r1, #0x40000000		@ enable access to FPU
	VFPFMXR	FPEXC, r1
	VFPFMRX	r1, FPSCR
	str	r1, [r8, #CTX_FPSCR]
	isb
	add	r9, r8, #CTX_VFP_REGS

	VFPFSTMIA r9, r12	@ save out (16 or 32)*8B of FPU registers
	VFPFMXR	FPEXC, r2
	mrc	p15, 0, r3, c1, c0, 2	@ restore original FPEXC/CPACR
#endif
@	mrc	p15, 0, r0, c15, c0, 1	@ diag
@	str	r0, [r8, #CTX_DIAGNOSTIC]

	add	r9, r8, #CTX_TTBR0
	mrc	p15, 0, r0, c2, c0, 0	@ TTBR0
	mrc	p15, 0, r1, c2, c0, 1	@ TTBR1
	mrc	p15, 0, r2, c2, c0, 2	@ TTBCR
	mrc	p15, 0, r3, c3, c0, 0	@ domain access control reg
	mrc	p15, 0, r4, c7, c4, 0	@ PAR
	mrc	p15, 0, r5, c10, c2, 0	@ PRRR
	mrc	p15, 0, r6, c10, c2, 1	@ NMRR
	mrc	p15, 0, r7, c12, c0, 0	@ VBAR
	stmia	r9!, {r0-r7}
	mrc	p15, 0, r0, c13, c0, 1	@ CONTEXTIDR
	mrc	p15, 0, r1, c13, c0, 2	@ TPIDRURW
	mrc	p15, 0, r2, c13, c0, 3	@ TPIDRURO
	mrc	p15, 0, r3, c13, c0, 4	@ TPIDRPRW
	stmia	r9, {r0-r3}

	cps	0x1f			@ SYS mode
	add	r9, r8, #CTX_SYS_SP
	stmia	r9, {sp,lr}

	cps	0x17			@ Abort mode
	mrs	r12, spsr
	add	r9, r8, #CTX_ABT_SPSR
	stmia	r9, {r12,sp,lr}

	cps	0x12			@ IRQ mode
	mrs	r12, spsr
	add	r9, r8, #CTX_IRQ_SPSR
	stmia	r9, {r12,sp,lr}

	cps	0x1b			@ Undefined mode
	mrs	r12, spsr
	add	r9, r8, #CTX_UND_SPSR
	stmia	r9, {r12,sp,lr}

	mov	r0, r8
	add	r1, r8, #CTX_FIQ_SPSR
	cps	0x11			@ FIQ mode
	mrs	r7, spsr
	stmia	r1, {r7-r12,sp,lr}

	cps	0x13			@ back to SVC
	mov	r8, r0

#if 0
	/* Save CP14 debug controller context */
	add	r9, r8, #CTX_CP14_REGS
	mrc	p14, 0, r0, c0, c1, 0	@ DSCR
	mrc	p14, 0, r1, c0, c6, 0	@ WFAR
	mrc	p14, 0, r2, c0, c7, 0	@ VCR
	mrc	p14, 0, r3, c7, c9, 6	@ CLAIM
	stmia	r9, {r0-r3}

	add	r9, r8, #CTS_CP14_BKPT_0
	mrc	p14, 0, r2, c0, c0, 4
	mrc	p14, 0, r3, c0, c0, 5
	stmia	r9!, {r2-r3}     	@ BRKPT_0
	mrc	p14, 0, r2, c0, c1, 4
	mrc	p14, 0, r3, c0, c1, 5
	stmia	r9!, {r2-r3}     	@ BRKPT_0
	mrc	p14, 0, r2, c0, c2, 4
	mrc	p14, 0, r3, c0, c2, 5
	stmia	r9!, {r2-r3}     	@ BRKPT_0
	mrc	p14, 0, r2, c0, c3, 4
	mrc	p14, 0, r3, c0, c3, 5
	stmia	r9!, {r2-r3}     	@ BRKPT_0
	mrc	p14, 0, r2, c0, c4, 4
	mrc	p14, 0, r3, c0, c4, 5
	stmia	r9!, {r2-r3}     	@ BRKPT_0
	mrc	p14, 0, r2, c0, c5, 4
	mrc	p14, 0, r3, c0, c5, 5
	stmia	r9!, {r2-r3}     	@ BRKPT_0

	add	r9, r8, #CTS_CP14_WPT_0
	mrc	p14, 0, r2, c0, c0, 6
	mrc	p14, 0, r3, c0, c0, 7
	stmia	r9!, {r2-r3}     	@ WPT_0
	mrc	p14, 0, r2, c0, c1, 6
	mrc	p14, 0, r3, c0, c1, 7
	stmia	r9!, {r2-r3}     	@ WPT_0
	mrc	p14, 0, r2, c0, c2, 6
	mrc	p14, 0, r3, c0, c2, 7
	stmia	r9!, {r2-r3}     	@ WPT_0
	mrc	p14, 0, r2, c0, c3, 6
	mrc	p14, 0, r3, c0, c3, 7
	stmia	r9!, {r2-r3}     	@ WPT_0
#endif
#ifdef CONFIG_CACHE_L2X0
	/* copied from ns2816 sample code,
	 * if smp & cpuid=0, clean&invalidate L2 cache */
	/* this need modified for smp
	 * sudpend/resume,save l2 configure needed
	 */
	cpu_id	r4
	cmp	r4, #0
	bne	__cortex_a9_save_clean_cache
	mov32	r4, (NS2816_L220_BASE-IO_DEV_PHYS+IO_DEV_VIRT)
	add	r9, r8, #CTX_L2_CTRL
	ldr	r0, [r4, #L2X0_CTRL]
	ldr	r1, [r4, #L2X0_AUX_CTRL]
	ldr	r2, [r4, #L2X0_TAG_LATENCY_CTRL]
	ldr	r3, [r4, #L2X0_DATA_LATENCY_CTRL]
	ldr	r4, [r4, #L2X0_PREFETCH_CTRL]
	stmia	r9, {r0-r4}
#endif


__cortex_a9_save_clean_cache:
	mov	r10, r8
	add	r9, r10, #(CONTEXT_SIZE_WORDS)
	add	r9, r9, #(L1_CACHE_BYTES-1)
	bic	r10, r10, #(L1_CACHE_BYTES-1)
	bic	r9, r9, #(L1_CACHE_BYTES-1)

3:	mcr	p15, 0, r10, c7, c10, 1
	add	r10, r10, #L1_CACHE_BYTES
	cmp	r10, r9
	blo	3b
	dsb

	translate r10, r8, r1

	mov	r0, #0
	mcr	p15, 0, r0, c1, c0, 1	@ exit coherency
	isb
	cpu_id	r0
	mov32	r1, (NS2816_SCU_BASE-IO_DEV_PHYS+IO_DEV_VIRT+0xC)
	mov	r3, r0, lsl #2
	mov	r2, #0xf
	mov	r2, r2, lsl r3
	str	r2, [r1]		@ invalidate SCU tags for CPU

	mov	r8, r10
/*	cmp	r0, #0
	bne	__put_cpu_in_reset 
*/
#ifdef CONFIG_CACHE_L2X0
	/* clean out the dirtied L2 lines, since all power transitions
	 * cause the cache state to get invalidated (although S1 & S2 
	 * preserve the data in the L2, the control words (L2X0_CTRL,
	 * L2X0_AUX_CTRL, etc.) need to be cleaned to L3 so that they
	 * will be visible on reboot.  skip this for S5, since the L2 cache
	 * will be shutdown before we reach this point */

	cmp sp, #NS2816_PM_SUSPEND_S3
	beq __l2_clean_done
	mov32   r0, (NS2816_L220_BASE-IO_DEV_PHYS+IO_DEV_VIRT)
	/* count out context physical address, to flush data from L2X0 to L3 */
	add r3, r8, #(CONTEXT_SIZE_WORDS)
	bic r8, r8, #0x1f
	add r3, r3, #0x1f
4:  str r8, [r0, #L2X0_CLEAN_LINE_PA]
	add r8, r8, #32 
	cmp r8, r3
	blo 4b 
5:  ldr r1, [r0, #L2X0_CLEAN_LINE_PA]
	tst r1, #1
	bne 5b 
	mov r1, #0
	str r1, [r0, #L2X0_CACHE_SYNC]
6:  ldr r1, [r0, #L2X0_CACHE_SYNC]
	tst r1, #1
	bne 6b 
__l2_clean_done:
#endif
#define NS2810_PRCM_BASE 0x051b0000
update_sys_pmstat:

	mov32   r0, (NS2816_SCM_BASE-IO_DEV_PHYS+IO_DEV_VIRT)
	str	  sp, [r0, #SCM_SYS_STAT_OFFSET]
/* change page table pointer to ns2816_pgd_phys, so that IRAM
         * and MMU shut-off will be mapped virtual == physical */
        adr     r3, __tear_down_master_data
        ldr     r3, [r3]                @ &ns2816_pgd_phys
        ldr     r3, [r3]
        orr     r3, r3, #TTB_FLAGS
        mov     r2, #0 
        mcr     p15, 0, r2, c13, c0, 1  @ reserved context
        isb
        mcr     p15, 0, r3, c2, c0, 0   @ TTB 0
        isb

	adr	r3,addr_switch
	translate r4,r3,r5
	bx	r4

addr_switch:
	/* 
	 * If you want to check function: ns2816_resume without really suspension,
	 * you can read function ns2816_resume's PA address from SCM, and disable mmu,
	 * after invalidate Icache & Dcache & TLB, jumping to ns2816_resume
	 *
	 * But if the really suspend-then-resume process is to be called, to ensure not
	 * to access DDR memory after DDR-self-refresh, we must disable mmu, invalidate
	 * Icache & Dcache & TLB, jumping to IRAM_PA_DRRESSS where __tear_down_master()
	 * is copied to.
	 */
	cmp	sp, #0x2
	bne	ddr_need_self_refresh

/*clock gating for hotplug*/
	mov32	r3, __ns2816_clk_gating
	translate r4,r3,r5
	bx	r3
/*power gating for hotplug*/
/*
        mov32   r3, (__ns2816_power_off)
	translate r4,r3,r5
	mov	r3,r4
	b	clean_sys_ctrl
*/

ddr_need_self_refresh:
        mov32   r3, (NS2816_IRAM_CODE_AREA)
clean_sys_ctrl:
	mrc  p15, 0, r0, c1, c0, 0   @SCTLR
	bic  r0, r0, #0x1            @disable mmu
	bic  r0, r0, #(0x1 << 12)    @disable I cache
	bic  r0, r0, #(0x1 << 2)     @disable D cache
	bic  r0, r0, #(0x1 << 11)    @disable program flow prediction
	dsb
	mcr  p15, 0, r0, c1, c0, 0

	isb
	bx	r3

ENDPROC(__cortex_a9_save)
ENTRY(__cortex_a9_save_size)
	.word . - __cortex_a9_save
ENDPROC(__cortex_a9_save_size)

/*
 * sp as mode,
 * modified r0  
 */
	.align L1_CACHE_SHIFT
ENTRY(__ns2816_clk_gating)
	mov32	r0, (SCM_CPU1_FLOW_REG-IO_DEV_PHYS+IO_DEV_VIRT)
	ldr	r1, [r0]
	bic	r1, #CPU1_ON
	str	r1, [r0]
	dsb

#ifdef CPU1_SHUTDOWN
	mov32	r0, (NS2816_SCU_BASE+8-IO_DEV_PHYS+IO_DEV_VIRT)
	ldr	r1, [r0]
	orr	r1, #(3<<8);
	str	r1, [r0]
	dsb

cpu1_off:	
	wfi	@clock gating
	b	cpu1_off
#else
	wfi
#endif
	mrc	p15, 0, r0, c1, c0, 1
	orr	r0, r0, #(1 << 6) | (1 << 0)	@ re-enable coherency
	mcr	p15, 0, r0, c1, c0, 1
	dsb
	isb

	adr	r0,__ns2816_resume
	bx	r0;

/*#endif*/
ENDPROC(__ns2816_clk_gating)

/*
 * sp as mode,
 * modified r0  
 */
	.align L1_CACHE_SHIFT
ENTRY(__ns2816_power_off)
sleep:
	wfi	@power off
	b	sleep
/*#ifdef CONFIG_CPU_IDLE*/
	b	wfi_resume
/*reset*/
/*
reset_core:
	mov32	r0, (NS2816_PRCM_BASE-IO_DEV_PHYS+IO_DEV_VIRT)
	ldr	r11, [r0, #0x14]
	bic	r11,r11,#(5<<7)
	str	r11, [r0, #0x14]

	mov	r10, #(5<<7)
	orr	r11, r10
	str	r11, [r0, #0x14]
	b	reset_core
*/
/*resume*/
wfi_resume:
	mrc	p15, 0, r0, c1, c0, 1
	orr	r0, r0, #(1 << 6) | (1 << 0)	@ re-enable coherency
	mcr	p15, 0, r0, c1, c0, 1
	dsb
	isb

	adr	r0,__ns2816_resume
	bx	r0;

/*#endif*/
ENDPROC(__ns2816_power_off)

/*
 *
 *  __tear_down_master(r8 = context virtual address, sp = power state )
 *
 *    Go into WFI if power state = S1, or set DDR go into self refresh,
 *    then power off Core when power state = S3. Be sure MMU&L1Cache&TLB
 *    is disable before that.
 */

#define	NS2816_PL310_PM_CTL	(0x05042f80)

	.align L1_CACHE_SHIFT
ENTRY(__tear_down_master)
__tear_down_master:
	mov32	r4, (NS2816_DDR_CFG_BASE)
ddr_disable_port:
	ldr	r1, [r4, #DDR_CCR_OFFSET]
	bic	r1, #DDR_CCR_HOST_EN_BIT
	str	r1, [r4, #DDR_CCR_OFFSET]
ddr_flush:
	ldr	r1, [r4, #DDR_CCR_OFFSET]
	orr	r1, #DDR_CCR_FLUSH_BIT
	str	r1, [r4, #DDR_CCR_OFFSET]
wait_for_flush_done:
	dsb
	ldr	r1, [r4, #DDR_CCR_OFFSET]
	tst	r1, #DDR_CCR_FLUSH_BIT
	bne	wait_for_flush_done

ddr_precharge_all:
	ldr    	r1, [r4, #DDR_DCR_OFFSET]
	bic    	r1, #DDR_DCR_CMD_BITS_MASK
	orr    	r1, #DDR_CMD_PRECHARGE_ALL
	orr    	r1, #DDR_CMD_EXEC_BIT
	orr    	r1, #DDR_DCR_RNKALL_BIT
	str    	r1, [r4, #DDR_DCR_OFFSET]
wait_for_precharge_all_done:
	dsb
	ldr	r1, [r4, #DDR_DCR_OFFSET]
	tst	r1, #DDR_CMD_EXEC_BIT
	bne	wait_for_precharge_all_done

ddr_self_refresh:
	ldr    	r1, [r4, #DDR_DCR_OFFSET]
	bic    	r1, #DDR_DCR_CMD_BITS_MASK
	orr    	r1, #DDR_CMD_SELF_REFRESH
	orr    	r1, #DDR_CMD_EXEC_BIT
	orr    	r1, #DDR_DCR_RNKALL_BIT
	str    	r1, [r4, #DDR_DCR_OFFSET]
wait_for_self_refresh_done:
	dsb
	ldr    	r1, [r4, #DDR_DCR_OFFSET]
	tst	r1, #DDR_CMD_EXEC_BIT
	bne	wait_for_self_refresh_done

enable_cpu0_1_shutdown:
	mov32	r4, (NS2816_PRCM_BASE)
	
	ldr	r6, [r4, #0x14]
	orr	r5, r6, #(3 << 12)	
	str	r5, [r4, #0x14]

	dsb
suspend_l2_scu:
	mov32	r4, (NS2816_SCU_BASE)

	mov	r5, #0
	str	r5, [r4, #0]

	mov	r5, #(3 << 5)
	str	r5, [r4, #0]
	dsb

	mov32	r0, SCM_CPU1_FLOW_REG
wait_for_cpu1_off:
	ldr	r1, [r0]
	tst	r1, #CPU1_ON
	bne	wait_for_cpu1_off

	mov32	r6, (NS2816_PL310_PM_CTL)
	mov	r7, #1
	str	r7, [r6, #0]
	dsb
#ifdef	CPU1_SHUTDOWN
	mov	r7, #3
	str	r7, [r6, #0]
	dsb
#endif

wait_for_power_off:	
	wfi
	b	wait_for_power_off

ENDPROC(__tear_down_master)

.type   __tear_down_master_data, %object
__tear_down_master_data:
        .long   ns2816_pgd_phys
 
ENTRY(__tear_down_master_size)
    .word   . - __tear_down_master
ENDPROC(__tear_down_master_size)


	.align L1_CACHE_SHIFT
ENTRY(__ns2816_resume)
#ifdef CONFIG_CACHE_L2X0
	cpu_id	r0
	ctx_ptr	r8, r9
	cmp	r0, #0
	bne	restore_context

	mov32	r9, (NS2816_L220_BASE-IO_DEV_PHYS+IO_DEV_VIRT)
	add	r10, r8, #CTX_L2_CTRL
	ldmia	r10, {r3-r7}
	str	r5, [r9, #L2X0_TAG_LATENCY_CTRL]
	str	r6, [r9, #L2X0_DATA_LATENCY_CTRL]
	str	r7, [r9, #L2X0_PREFETCH_CTRL]
	str	r4, [r9, #L2X0_AUX_CTRL]
	cmp	r0, #0

	@beq	__reenable_l2x0

	mov32	r0, 0xffff
	str	r0, [r9, #L2X0_INV_WAY]
1:	ldr	r1, [r9, #L2X0_INV_WAY]
	tst	r1, r0
	bne	1b
	mov	r0, #0
	str	r0, [r9, #L2X0_CACHE_SYNC]
	
	b	restore_context
__reenable_l2x0:
	mov	r5, #0
	mcr	p15, 0, r5, c8, c3, 0	@ invalidate TLB
	mcr	p15, 0, r5, c7, c5, 6	@ flush BTAC
	mcr	p15, 0, r5, c7, c5, 0	@ flush instruction cache
	dsb
	isb
	str	r3, [r9, #L2X0_CTRL]
restore_context:
#endif
  	cps     0x13
	ctx_ptr r0, r9

        cps     0x11                    @ FIQ mode
        add     r1, r0, #CTX_FIQ_SPSR
        ldmia   r1, {r7-r12,sp,lr}
        msr     spsr_fsxc, r7

        cps     0x12                    @ IRQ mode
        add     r1, r0, #CTX_IRQ_SPSR
        ldmia   r1, {r12, sp, lr}
        msr     spsr_fsxc, r12

        cps     0x17                    @ abort mode
        add     r1, r0, #CTX_ABT_SPSR
        ldmia   r1, {r12, sp, lr}
        msr     spsr_fsxc, r12

        cps     0x1f                    @ SYS mode
        add     r1, r0, #CTX_SYS_SP
        ldmia   r1, {sp, lr}

        cps     0x1b                    @ Undefined mode
        add     r1, r0, #CTX_UND_SPSR
        ldmia   r1, {r12, sp, lr}
        msr     spsr_fsxc, r12

        cps     0x13                    @ back to SVC
        mov     r8, r0

	 add     r9, r8, #CTX_CSSELR
        ldmia   r9, {r0-r3}

        mcr     p15, 2, r0, c0, c0, 0   @ csselr
        mcr     p15, 0, r1, c1, c0, 0   @ sctlr
        mcr     p15, 0, r2, c1, c0, 1   @ actlr
        mcr     p15, 0, r3, c15, c0, 0  @ pctlr

        add     r9, r8, #CTX_TTBR0
        ldmia   r9!, {r0-r7}

        mcr     p15, 0, r4, c7, c4, 0   @ PAR
        mcr     p15, 0, r7, c12, c0, 0  @ VBAR
        mcr     p15, 0, r3, c3, c0, 0   @ domain access control reg
        isb
        mcr     p15, 0, r2, c2, c0, 2   @ TTBCR
        isb
        mcr     p15, 0, r5, c10, c2, 0  @ PRRR
        isb
        mcr     p15, 0, r6, c10, c2, 1  @ NMRR
        isb

        ldmia   r9, {r4-r7}

        mcr     p15, 0, r5, c13, c0, 2  @ TPIDRURW
        mcr     p15, 0, r6, c13, c0, 3  @ TPIDRURO
        mcr     p15, 0, r7, c13, c0, 4  @ TPIDRPRW

        ldmia   r8, {r5-r7, lr}

 /* perform context switch to previous context */
        mov     r9, #0
        mcr     p15, 0, r9, c13, c0, 1  @ set reserved context
        isb
        mcr     p15, 0, r0, c2, c0, 0   @ TTBR0
        isb
        mcr     p15, 0, r4, c13, c0, 1  @ CONTEXTIDR
        isb
        mcr     p15, 0, r1, c2, c0, 1   @ TTBR1
        isb

        mov     r4, #0
        mcr     p15, 0, r4, c8, c3, 0   @ invalidate TLB
        mcr     p15, 0, r4, c7, c5, 6   @ flush BTAC
        mcr     p15, 0, r4, c7, c5, 0   @ flush instruction cache
        dsb
        isb

        mov     sp, r5
        msr     cpsr_cxsf, r6
        msr     spsr_cxsf, r7

  /* Restore CP14 debug controller context */
#if 0
        add     r9, r8, #CTX_CP14_REGS
        ldmia   r9, {r0-r3}
        mcr     p14, 0, r1, c0, c6, 0   @ WFAR
        mcr     p14, 0, r2, c0, c7, 0   @ VCR
        mcr     p14, 0, r3, c7, c8, 6   @ CLAIM

        add     r9, r8, #CTS_CP14_BKPT_0
        ldmia   r9!, {r2-r3}            @ BRKPT_0
        mcr     p14, 0, r2, c0, c0, 4
        mcr     p14, 0, r3, c0, c0, 5
        ldmia   r9!, {r2-r3}            @ BRKPT_0
        mcr     p14, 0, r2, c0, c1, 4
        mcr     p14, 0, r3, c0, c1, 5
        ldmia   r9!, {r2-r3}            @ BRKPT_0
        mcr     p14, 0, r2, c0, c2, 4
        mcr     p14, 0, r3, c0, c2, 5
        ldmia   r9!, {r2-r3}            @ BRKPT_0
        mcr     p14, 0, r2, c0, c3, 4
        mcr     p14, 0, r3, c0, c3, 5
        ldmia   r9!, {r2-r3}            @ BRKPT_0
        mcr     p14, 0, r2, c0, c4, 4
        mcr     p14, 0, r3, c0, c4, 5
        ldmia   r9!, {r2-r3}            @ BRKPT_0
        mcr     p14, 0, r2, c0, c5, 4
        mcr     p14, 0, r3, c0, c5, 5

	add     r9, r8, #CTS_CP14_WPT_0
        ldmia   r9!, {r2-r3}            @ WPT_0
        mcr     p14, 0, r2, c0, c0, 6
        mcr     p14, 0, r3, c0, c0, 7
        ldmia   r9!, {r2-r3}            @ WPT_0
        mcr     p14, 0, r2, c0, c1, 6
        mcr     p14, 0, r3, c0, c1, 7
        ldmia   r9!, {r2-r3}            @ WPT_0
        mcr     p14, 0, r2, c0, c2, 6
        mcr     p14, 0, r3, c0, c2, 7
        ldmia   r9!, {r2-r3}            @ WPT_0
        mcr     p14, 0, r2, c0, c3, 6
        mcr     p14, 0, r3, c0, c3, 7
        isb
        mcr     p14, 0, r0, c0, c2, 2   @ DSCR
        isb
#endif

#ifdef CONFIG_VFPv3
        orr     r4, lr, #0xF00000
        mcr     p15, 0, r4, c1, c0, 2   @ enable coproc access
	isb
        mov     r5, #0x40000000
        VFPFMXR FPEXC, r5               @ enable FPU access
        add     r9, r8, #CTX_VFP_REGS
        add     r7, r8, #CTX_FPEXC
        VFPFLDMIA r9, r10
        ldmia   r7, {r0, r4}
        VFPFMXR FPSCR, r4
        VFPFMXR FPEXC, r0
#endif
        mcr     p15, 0, lr, c1, c0, 2   @ cpacr (loaded before VFP)
	isb

@	ldr	r9, [r8, #CTX_DIAGNOSTIC]
@	mcr	p15, 0, r9, c15, c0, 1	@ diag


        /* finally, restore the stack and return */
        ldmfd   sp!, {r3-r12, lr}
        msr     cpsr_fsxc, r3           @ restore original processor mode
	isb
        mov     pc, lr
ENDPROC(__ns2816_resume)
/*
 *	__ns2816_resume()
 *
 *	 reloads the volatile CPU state from the context area
 *	 the MMU should already be enabled using the secondary_data
 *	 page tables for cpu_up before this function is called, and the
 *	 CPU should be coherent with the SMP complex
 *	 Reconfigures the L2 cache following a power event.
 */

ENTRY(__ns2816_resume_size)
  .word   . - __ns2816_resume
ENDPROC(__ns2816_resume_size)
	
	.align L1_CACHE_SHIFT
ENTRY(__shut_off_mmu)
	mrc	p15, 0, r3, c1, c0, 0
	movw	r2, #(1<<12) | (1<<11) | (1<<2) | (1<<0)
	bic	r3, r3, r2
	dsb
	mcr	p15, 0, r3, c1, c0, 0
	isb
	bx	r9
ENDPROC(__shut_off_mmu)


/*
 *	__invalidate_l1
 *
 *	  Invalidates the L1 data cache (no clean) during initial boot of
 *	  a secondary processor
 *
 *	  Corrupted registers: r0-r6
 */
__invalidate_l1:
	mov	r0, #0
	mcr	p15, 2, r0, c0, c0, 0
	mrc	p15, 1, r0, c0, c0, 0

	movw	r1, #0x7fff
	and	r2, r1, r0, lsr #13

	movw	r1, #0x3ff

	and	r3, r1, r0, lsr #3  @ NumWays - 1
	add	r2, r2, #1	@ NumSets

	and	r0, r0, #0x7
	add	r0, r0, #4	@ SetShift

	clz	r1, r3		@ WayShift
	add	r4, r3, #1	@ NumWays
1:	sub	r2, r2, #1	@ NumSets--
	mov	r3, r4		@ Temp = NumWays
2:	subs    r3, r3, #1	@ Temp--
	mov	r5, r3, lsl r1
	mov	r6, r2, lsl r0
	orr	r5, r5, r6	@ Reg = (Temp<<WayShift)|(NumSets<<SetShift)
	mcr	p15, 0, r5, c7, c6, 2
	bgt	2b
	cmp	r2, #0
	bgt	1b
	dsb
	isb
	bx	lr
ENDPROC(__invalidate_l1)

/*
 *	__invalidate_cpu_state
 *
 *	 Invalidates volatile CPU state (SCU tags, caches, branch address
 *	 arrays, exclusive monitor, etc.) so that they can be safely enabled
 *	 instruction caching and branch predicition enabled as early as
 *	 possible to improve performance
 */
ENTRY(__invalidate_cpu_state)
	clrex
	mov	r0, #0
	mcr	p15, 0, r0, c1, c0, 1	@ disable SMP, prefetch, broadcast
	isb
	mcr	p15, 0, r0, c7, c5, 0	@ invalidate BTAC, i-cache
	mcr	p15, 0, r0, c7, c5, 6	@ invalidate branch pred array
	mcr	p15, 0, r0, c8, c7, 0	@ invalidate unified TLB
	dsb
	isb

	cpu_id	r0
	mov32	r1, (NS2816_SCU_BASE + 0xC)
	mov	r0, r0, lsl #2
	mov	r2, #0xf
	mov	r2, r2, lsl r0
	str	r2, [r1]		@ invalidate SCU tags for CPU

	dsb
	mov	r0, #0x1800
	@mov	r0, #0x0000
	mcr	p15, 0, r0, c1, c0, 0	@ enable branch prediction, i-cache
	isb
	mov	r10, lr			@ preserve lr of caller
	bl	__invalidate_l1		@ invalidate data cache
	bx	r10			@ return
ENDPROC(__invalidate_cpu_state)


	.align L1_CACHE_SHIFT
ENTRY(__ns2816_lp_reset)
	bl __invalidate_cpu_state
/*power on neon*/
       cpu_id  r3
       add     r3, #10
       mov     r4, #1
       lsl     r3, r4, r3
       /*negetive edge for neon power on*/
       mov32   r4, (NS2816_PRCM_BASE)
       ldr     r5, [r4, #0x14]
       orr     r5, r3
       str     r5, [r4, #0x14]
       dsb
       bic     r5, r3
       str     r5, [r4, #0x14] 
       dsb

#ifdef CONFIG_SMP
enable_coherency:
	mrc	p15, 0, r0, c1, c0, 1
	orr	r0, r0, #(1 << 6) | (1 << 0)	@ re-enable coherency
	mcr	p15, 0, r0, c1, c0, 1

	cpu_id	r0
	cmp	r0, #0
	beq	reset_cpu1

	/*cpu1 will run to here*/
	mov32	r0, SCM_CPU1_FLOW_REG
	ldr	r1, [r0]
	and	r1, #CPU1_FLOW_MASK
	cmp	r1, #CPU1_FLOW_BOOT
	beq	resume_context
	cmp	r1, #CPU1_FLOW_HOTPLUG
	beq	resume_context

	cmp	r1, #CPU1_FLOW_RESUME
	beq	enable_scu
	
	/*should not run to here!*/	
reset_halt:
	wfi
	b	reset_halt	
	/*resume from suspend to ram need to do this*/
enable_scu:
	mov32	r0, NS2816_SCU_BASE
	ldr	r1, [r0]
	orr	r1, r1, #1
	str	r1, [r0]	@enable SCU
	dsb
	isb
	wfi
	b	resume_context
reset_cpu1:
	/*set cpu1 flow control*/
	mov32	r0, SCM_CPU1_FLOW_REG
	mov	r1, #(CPU1_FLOW_RESUME | CPU1_ON)
	str	r1, [r0]
	dsb

	/* maybe cpu1 be wfi status in romcode, and set power 
	 * status = 0x0300, to shutdown cpu1
         */
	
	mov32	r0, NS2816_SCU_BASE
	ldr	r1, [r0, #0x8]
	orr	r1, r1, #(3<<8)
	str	r1, [r0, #8]	@shutdown cpu1
	dsb

	/*software reset cpu1*/
/*	cpu keep power off while resume.
	mov32	r0, NS2816_PRCM_BASE
	ldr	r1, [r0,#0x14]	
	bic	r1, #(1<<8)
	str	r1, [r0,#0x14]
	orr	r1, #(1<<8)
	str	r1, [r0,#0x14]
*/

#endif
#ifdef DEBUG_STR_MODE
	b .
#endif
resume_context:
        adr     r4, __ns2816_lp_data                                          
        ldmia   r4, {r5, r7, r12}       
        mov     r1, r12                 @ ctx_restore = __ns2816_resume   
        sub     r4, r4, r5
        ldr     r0, [r7, r4]            @ pgdir = ns2816_pgd_phys

        b       __return_to_virtual

ENDPROC(__ns2816_lp_reset)
        .type   __ns2816_lp_data, %object
__ns2816_lp_data:
        .long   .
        .long   ns2816_pgd_phys
        .long   __ns2816_resume
        .size   __ns2816_lp_data, . - __ns2816_lp_data

/*
 *	__return_to_virtual(unsigned long pgdir, void (*ctx_restore)(void))
 *
 *	  Restores a CPU to the world of virtual addressing, using the
 *	  specified page tables (which must ensure that a VA=PA mapping
 *	  exists for the __enable_mmu function), and then jumps to
 *	  ctx_restore to restore CPU context and return control to the OS
 */
	.align L1_CACHE_SHIFT
ENTRY(__return_to_virtual)
	orr	r8, r0, #0x6A		@ TTB IRGN_WBWA, OC_RGN_WBWA, S, NOS
	mov	lr, r1			@ "return" to ctx_restore
	mov	r3, #0
	mcr	p15, 0, r3, c2, c0, 2	@ TTB control register
	mcr	p15, 0, r8, c2, c0, 1	@ load TTBR1
	isb

	mov	r0, #0x1f
	mcr	p15, 0, r0, c3, c0, 0	@ domain access register
	isb

	mov32	r0, 0xff0a89a8
	mov32	r1, 0xc0e0c4e0
	mcr	p15, 0, r0, c10, c2, 0	@ PRRR
	mcr	p15, 0, r1, c10, c2, 1	@ NMRR
	mrc	p15, 0, r0, c1, c0, 0
	isb
	mov32	r1, 0x0120c302
	bic	r0, r0, r1
	mov32	r1, 0x10c03c7d
	orr	r0, r0, r1

#ifdef CONFIG_ALIGNMENT_TRAP
	orr	r0, r0, #0x2
#else
	bic	r0, r0, #0x2
#endif
	mov	r1, #(domain_val(DOMAIN_USER, DOMAIN_MANAGER) | \
		      domain_val(DOMAIN_KERNEL, DOMAIN_MANAGER) | \
		      domain_val(DOMAIN_TABLE, DOMAIN_MANAGER) | \
		      domain_val(DOMAIN_IO, DOMAIN_CLIENT))
	mcr	p15, 0, r1, c3, c0, 0	@ domain access register
	mcr	p15, 0, r8, c2, c0, 0	@ TTBR0
	isb
	b	__turn_mmu_on_again
	andeq	r0, r0, r0
	andeq	r0, r0, r0
	andeq	r0, r0, r0
	andeq	r0, r0, r0
ENDPROC(__return_to_virtual)

/*
 *	__turn_mmu_on_again
 *
 *	  does exactly what it advertises: turns the MMU on, again
 *	  jumps to the *virtual* address lr after the MMU is enabled.
 */
	.align	L1_CACHE_SHIFT
__turn_mmu_on_again:
	mov	r0, r0
	mcr	p15, 0, r0, c1, c0, 0	@ SCTLR
	mrc	p15, 0, r3, c0, c0, 0	@ MIDR
	isb
	mov	r3, r3
	mov	r3, lr
	bx	lr
ENDPROC(__turn_mmu_on_again)

	.align	L1_CACHE_SHIFT
__ns2816_putc:
	mov32 r5, 0x05150000
putc_loop:
	ldr   r6, [r5, #20]
	tst   r6, #32
	beq   putc_loop
	str   r4, [r5]			@r4: save char data
ENDPROC(__ns2816_putc)


	.align	L1_CACHE_SHIFT
__ns2816_puthex:
	mov	r7, #8
	lsr	r4, r2, #28		@r2: save register data
	cmp	r4, #9
	add	r4, r4, #48	
	addgt	r4, r4, #39
	b	__ns2816_putc
	lsl	r2, r2, #4					
        sub	r7, r7, #1		
	mov	r4, #32
	b	__ns2816_putc
ENDPROC(__ns2816_puthex)
/*
 *    wake up for power gate.
 *    resume for cpu0,
 */
	.align L1_CACHE_SHIFT
ENTRY(__ns2816_iram_entry)
__ns2816_iram_entry:
	B reset_handler
	B undef_handler
	B swi_handler
	B prefetch_abort        
	B data_abort            
	B error                 
	B irq_handler                 
	B fiq_handler 
undef_handler:
mov r5,#1
b halt
swi_handler:
mov r5,#2
b halt
prefetch_abort:
mov r5,#3
b halt
data_abort:
mov r5,#4
b halt
error:  
mov r5,#5
b halt
irq_handler:  
mov r5,#6
b halt
fiq_handler:
mov r5,#7
halt:
b	.
cpu_id	r2
mov	r1, #9
sub	r2,r1,r2
mov	r1, #1
mov	r2,r1,lsl r2
mov32 	r1, 0x051b0014
ldr	r0, [r1]
bic	r0, r2 
str	r0, [r1]
orr	r0, r2
str	r0, [r1]
b .

reset_handler:
	cpu_id	r3
	cmp	r3, #0
	beq	way_back

	/*cpu1 wakeup before suspend to ram*/
	mov32	r0, SCM_CPU1_FLOW_REG
	ldr	r1, [r0]
	and	r1, #CPU1_FLOW_MASK
	cmp	r1, #CPU1_FLOW_SUSPEND
	bne	way_back
	
	/*disable power off*/
	mov32	r0, NS2816_SCU_BASE
	ldr	r1, [r0, #0x8]
	bic	r1, #(3<<8)
	str	r1, [r0, #0x8]	 
	dsb
	isb
wait:
	wfi
	b wait
way_back:
	mov32	r2, 0x051c0038
	ldr	r1, [r2]
	bx	r1	
ENDPROC(__ns2816_iram_entry)

ENTRY(__ns2816_iram_entry_size)
    .word   . - __ns2816_iram_entry
ENDPROC(__ns2816_iram_entry_size)


