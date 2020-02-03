	.text
	.file	"main.s"

# ---------------------------------------------
# divide
# ---------------------------------------------

 	.globl	divide
divide:                // a / b

# Store return address and get dsp

	mov r6, [&return]

# Load divisor mantissa into register r4:r5

	mov [&dsp], r6     // b
	mov [r6, 0], r4
	mov [r6, 1], r5

# Load dividend mantissa into register r2:r3

	sub 4, r6          // a
	mov [r6, 0], r2
	mov [r6, 1], r3	
	
# r0:r1 will become the result
	
	mov 0, r0      
	mov 0, r1           // R0:R1 will become the result
	
# We will loop 4 times

	mov 4, r6
	
# but first compute first digit
	
.LDivFirst:
	dsb r2, r4, r2
	dsc r3, r5, r3     // Subtract divisor
	adt 1, r0          // Only add result digit if no borrow (== carry) is produced
	bt .LDivFirst      // Subtract one more if no borrow

# For the first digit we shift divisor right (instead of dividend left)

	rr4 r4, r5, r4    // lower first
	sr4 r5, r5
	
	b .LDivMore      // branch to the restoring half of the loop
	
.LDLoop:

# Shift result one digit left

	rl4 r1, r0, r1   // higher first
	sl4 r0, r0
	
# Compute non restoring digit by repeatedly subtracting divisor

.LDivMinus:
	dsb r2, r4, r2
	dsc r3, r5, r3     // Subtract divisor
	adt 1, r0          // Only add result digit if no borrow (== carry) is produced
	bt .LDivMinus      // Subtract one more if no borrow

# Shift dividend left

	rl4 r3, r2, r3      // higher first
	sl4 r2, r2
	
# Shift result left, initialize last digit with 9

.LDivMore:
	rl4 r1, r0, r1     
	sl4 r0, r0         // Shift result one digit left
	add 9, r0          // Initialize result digit with 9 for restoring
	
# Compute the restoring digit by repeatedly adding divisor
	
.LDivPlus:
	dad r2, r4, r2
	dac r3, r5, r3     // Add divisor
	sbf 1, r0          // Only subtract if no carry
	bf .LDivPlus       // Add one more if no carry
	
# Shift dividend left

	rl4 r3, r2, r3      // higher first
	sl4 r2, r2
	
# Next digit 

	sub 1, r6
	bf .LDLoop
	
# Get exponents

	mov [&dsp], r6   // b
	mov [r6, 3], r5   // divisor exponent
	
	sub 4, r6        // a
	mov [r6, 3], r4   // divider exponent
	
# Store mantissa in the place of divider

	mov r0, [r6, 0]
	mov r1, [r6, 1]
	
# Subtract exponents and adjust sign
	
	dsb r4, r5, r3   // subtract exponents (and signs)
	and 0xf, r5      // select sign of b
	dad r3, r5, r3   // undo subtraction of b sign
	add r3, r5, r3   // add the b sign                         
	and 0xfff1, r3   // keep the bit sign only
	
# store exponent

	mov r3, [r6, 3]
	
# update dsp

	mov r6, [&dsp]   // Update dsp
	
# return
	mov [&return], pc


# ---------------------------------------------
# main
# ---------------------------------------------

	.globl	main
main:

# Load a, b inputs to data stack 

	mov [&dsp], r4   // load dsp to r4
	add 4, r4
	
	mov [&a], r0
	mov r0, [r4,0]
	mov [&a+1], r0
	mov r0, [r4,1]
	mov [&a+2], r0
	mov r0, [r4,2]
	mov [&a+3], r0
	mov r0, [r4,3]    // move a to pstack
	
	add 4, r4
	mov [&b], r0
	mov r0, [r4,0]
	mov [&b+1], r0
	mov r0, [r4,1]
	mov [&b+2], r0
	mov r0, [r4,2]
	mov [&b+3], r0
	mov r0, [r4,3]    // move b to pstack
	
	mov r4, [&dsp]

# call divide

	jl @divide
	
# load result

	mov [&dsp], r4   // load dsp to r4
	mov [r4,0], r0
	mov r0, [&result]
	mov [r4,1], r0
	mov r0, [&result+1]
	mov [r4,2], r0
	mov r0, [&result+2]
	mov [r4,3], r0
	mov r0, [&result+3]    // move pstack to result
	
	hlt




# ---------------------------------------------
# Initialized Data
# ---------------------------------------------

	.data
	.p2align 1
dsp:
	.short dstack-4       // preincrement stores, postdecrement loads
     
sp:
	.short pstack+512    // predecrement stores, postincrement loads
	
	.p2align 3
a:	.long 0x18465932
	.long 0x00100000      // +1.8465932e+01
b:	.long 0x78901234
	.long 0x00000000      // +7.8901234e+00


# ---------------------------------------------
# Uninitialized Data
# ---------------------------------------------
	
	.comm result,8,2       // reserve space in data memory for result
	.comm return,8,2       // tail call subroutine return address
	.comm dstack, 128, 8   // data stack, 128 bytes, 8 byte aligned, grows upward
	.comm pstack, 1024, 64 // program stack, 128 bytes, 64 bytes aligned, grows downward
	
	
	
	
	
	
	
	
