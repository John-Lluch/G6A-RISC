	.text
	.file	"main.s"

# ---------------------------------------------
# square root
# ---------------------------------------------

 	.globl	Squareroot
Squareroot:                // sqrt(a)

# Store return address

	mov r6, [&return]

# Load radicand address in r4

	mov [&dsp], r4     // a
	
# r0:r1 will become the radicand remainder
	
#	mov 0, r0
#	mov 0, r1           // R0:R1 will become the radicand remainder

# aux0, aux0+1 will become the accumlated root

//	mov r0, [&aux0]
//	mov r1, [&aux0+1]   // aux0, aux0+1 will become the accumlated root

# Check if exponent is an even number

	mov [r4, 3], r0
	and 0x10, r0      // Check if exponent is an even number
#	adt 0x10, r1       // If so, add 1 to exponent
#	mov r1, [r4, 3]    // Store exponent

# Load Radicand and initialize remaninder

	mov [r4, 0], r2     //
	mov [r4, 1], r3     // Load  radicand

	mov 0, r0           //
	mov 0, r1           // R0:R1 will become the radicand remainder

# If exponent was even we only need to shift once initially

	bt .LSqrtEvenExponent  // Branch if exponent was even

# Shift radicand into remainder (one)

	rl4 r0, r3, r0
	rl4 r3, r2, r3
	sl4 r2, r2          // Shift one digit

# Shift radicand into remainder (two)

.LSqrtEvenExponent:
	rl4 r0, r3, r0
	rl4 r3, r2, r3
	sl4 r2, r2          // Shift one digit

# Update shifted radicand

	mov r2, [r4, 0]
	mov r3, [r4, 1]     // Save shifted radicand for next iteration

	mov 0, r2
	mov 0, r3

# We will loop 6 times

	mov 6, r6

# Branch to sqrt entry

	b .LSqrtFirstEntry

# Shift next 2 digits of radicand into remainder

.LSqrtOuter:
	mov [r4, 0], r2
	mov [r4, 1], r3     // Load radicand for this iteration

	rl4 r1, r0, r1
	rl4 r0, r3, r0
	rl4 r3, r2, r3
	sl4 r2, r2          // Shift first digit

	rl4 r1, r0, r1
	rl4 r0, r3, r0
	rl4 r3, r2, r3
	sl4 r2, r2          // Shift second digit

	mov r2, [r4, 0]
	mov r3, [r4, 1]     // Save shifted radicand for next iteration

# Compute accumulated root, Si

	mov [&aux0], r2
	mov [&aux0+1], r3

	rl4 r3, r2, r3
	sl4 r2, r2

.LSqrtFirstEntry:
	mov r2, [&aux0]
	mov r3, [&aux0+1]  // Save for next iteration

# Compute 2*Si - 1

	dad r2, r2, r2
	dac r3, r3, r3
	dsb 1, r2
	dsc 0, r3

# Current digit

	mov 0, r5      // n

# Find radicator Zi = 2*Si + Yi, subtract repeatedly to determine digit

.LSqrtInner:
	dad 2, r2
	dac 0, r3
	dsb r0, r2, r0
	dsc r1, r3, r1   // Subtract radicator
	adt 1, r5        // Only add digit if no borrow (== carry) is produced
	bt .LSqrtInner   // Subtract one more if no borrow

# Restore remainder for next iteration

	dad r0, r2, r0
	dac r1, r3, r1

# Accumulate root digit

	add r5, [&aux0]

# Go for next one

	sub 1, r6
	bf .LSqrtOuter

# Store result in the place of radicand

	mov [&aux0], r0
	mov [&aux0+1], r1
	mov r0, [r4 ,0]
	mov r1, [r4 ,1]

# Adjust exponent to be half the original one and clear sign

	mov [r4, 3], r0    // load exponent
	sr4 r0, r0         // shift the exponent value to lower bits
	dad r0, r0, r1     // times 0.2
	dad r1, r1, r1     // times 0.4
	dad r1, r0, r1     // times 0.5
	dad 0x20, r1       // add 2 to compensate for two extra sqrt digits
	and 0xfff0, r1     // clear sign
	mov r1, [r4, 3]    // store exponent
	
# return
	mov [&return], pc


# ---------------------------------------------
# main
# ---------------------------------------------

	.globl	main
main:

# Load a inputs to data stack 

	mov [&dsp], r4   // load dsp to r4
	add 4, r4
	
	mov [&a], r0
	mov r0, [r4,0]
	mov [&a+1], r0
	mov r0, [r4,1]
	mov [&a+2], r0
	mov r0, [r4,2]
	mov [&a+3], r0
	mov r0, [r4,3]    // move a to dstack

	mov r4, [&dsp]

# call squareroot

	jl @Squareroot
	
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
a:
	.long 0x38598118
	.long 0x00300000      // +3.8598118e+01

# ---------------------------------------------
# Uninitialized Data
# ---------------------------------------------

	.comm return, 2, 2       // tail call subroutine return address
	.comm aux0, 8, 8         // reserved for auxiliary variable
	.comm aux1, 8, 8         // reserved for auxiliary variable
	.comm result, 8, 8       // reserved for result
	.comm dstack, 128, 8     // data stack, 128 bytes, 8 byte aligned, grows upward
	.comm pstack, 1024, 64   // program stack, 128 bytes, 64 bytes aligned, grows downward
	
	
	
	
	
	
	
	
