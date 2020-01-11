	.text
	.file	"main.c"

# ---------------------------------------------
# main
# ---------------------------------------------
	.globl	main
main:
	mov 100, a0          // assume 100 is the top of the stack address
	mov [a0, 0], r1      // get multiplier
	mov [a0, 1], r2      // get multiplicand 	
	add 1, a0            // increment stack address
	mov 0, r0
	mov r0, [a0, 0]      // set initial result to zero
	mov 16, r0           // initialise counter
.LMulHi
	sr1 r2, r2           // shift right the multiplicand
	adt r1, [a0, 0]      // conditionally accumulate the result
	sl1 r1, r1           // shift multiplier left
	sub 1, r0            // decrement counter
	bt- .LMulHi          // next iteration
.LMulDone
	// done, the stack pointer is already incremented 
	// and the result in the right memory location

# ---------------------------------------------
# Global Data
# ---------------------------------------------


