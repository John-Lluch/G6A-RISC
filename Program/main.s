	.text
	.file	"main.s"

# ---------------------------------------------
# main
# ---------------------------------------------
	.globl	main
main:
	mov [&a], r0
	add [&b], r0
	mov r0, [&result]
	hlt

# ---------------------------------------------
# Global Data
# ---------------------------------------------
	
#	.section VARS
	.data
a:	.short 33
b:	.short 44
	.comm result,2,2



# 	mov 100, a0          // assume 100 is the top of the stack address
# 	mov [a0, 0], r1      // get multiplier
# 	mov [a0, 1], r2      // get multiplicand 	
# 	add 1, a0            // increment stack address
# 	mov 0, r0
# 	mov r0, [a0, 0]      // set initial result to zero
# 	mov 16, r0           // initialise counter
# .LMulHi:
# 	sr1 r2, r2           // shift right the multiplicand
# 	adt r1, [a0, 0]      // conditionally accumulate the result
# 	sl1 r1, r1           // shift multiplier left
# 	sub 1, r0            // decrement counter
# 	bt .LMulHi           // next iteration
# .LMulDone:
# 	// done, the stack pointer is already incremented 
# 	// and the result in the right memory location
# 	
# 	
# 	
# # ---------------------------------------------
# # myprintstr
# # ---------------------------------------------
# 	.globl	myprintstr
# myprintstr:
# .LBB0_1:
# 	mov [a0, 0], r1
# 	cmp 0, r1
# 	bt .LBB0_3
# 	mov r1, [-1]
# 	add 1, r0
# 	b .LBB0_1
# .LBB0_3:
# 	mov lr, pc
# 	
# 	
# # ---------------------------------------------
# # printnum
# # ---------------------------------------------
# 	.globl	printnum
# printnum:
# 	mov	0, r1
# .LBB1_1:
# 	cmp	5, r1
# 	bt	.LBB1_6
# 	mov	48, r2
# 	add	r1, r1, a0
# 	mov	[a0, &.L__const.printnum.factors], a0
# .LBB1_3:
# 	cmp.ult	r0, a0
# 	bt	.LBB1_5
# 	sub	r0, a0, r0
# 	add	1, r2
# 	b	.LBB1_3
# .LBB1_5:
# 	mov	r2, [-1L]
# 	add	1, r1
# 	b	.LBB1_1
# .LBB1_6:
# 	mov lr, pc

# ---------------------------------------------
# Global Data
# ---------------------------------------------
#	.section	.rodata,"a",@progbits
#	.p2align	1
# .L__const.printnum.factors:
# 	.short	10000
# 	.short	1000
# 	.short	100
# 	.short	10
# 	.short	1



