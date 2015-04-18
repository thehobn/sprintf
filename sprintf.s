#sprintf!
#$a0 has the pointer to the buffer to be printed to
#$a1 has the pointer to the format string
#$a2 and $a3 have (possibly) the first two substitutions for the format string
#the rest are on the stack
#return the number of characters (ommitting the trailing '\0') put in the buffer
        .text

sprintf:	#(*outbuf, *format, . . .) outbuf.length
	#Prologue
		li $s0, 20	# Set sprintf's stack size here (used in prologue, epilogue, and retrieving arguments from outside stack frame) 
		sub $sp, $sp, $s0
		sw $ra, 0($sp)
		sw $a0, 4($sp)
		sw $a1, 8($sp)
		sw $a2, 12($sp)
	#Get number of additional arguments
		move $s2, $a1	# Initialize the format character pointer
		li $s3, 0 # Initialize the number of format arguments to 0 so we can safely increment it later
		findFormatArgumentCountLoop:
			lb $t0, ($s2)	# Load character from *format
			addi $s2, $s2, 1 # Increment to the next character
			beq $t0, '%', incrementFormatArgumentCount # Increment count on '%'
			returnForIncrementFormatArgumentCount: # Name is very self-descriptive
			bne $t0, 0, findFormatArgumentCountLoop	# Loop
			j findPercentageSigns	# Jumps to the next stage on finding null terminator
		incrementFormatArgumentCount:
			addi $s3, $s3, 1	# Increment number of format arguments
			j returnForIncrementFormatArgumentCount # Return to the loop
	#Find '%'s and call format to format them
	findPercentageSigns:
	li $s4, 0	# Initialize the counter to keep track of which additional argument we are on
	move $s1, $a0	# Initialize the outbuf character pointer
	move $s2, $a1
	findPercentageSignsLoop:	
		lb $t0, ($s2)	#Load current character being parsed
		beq $t0, 0, fin
		la $ra, back	#Load return address
		# Set arguments for format
			move $a0, $s1	#Remember to restore $a0
			move $a1, $s2	#Remember to restore $a1
			# Load the right additional argument into $a2 (arguments on stack!)
			#INSERT: Increment formatArgIndex (maybe in format?)
				beq $s4, 0, L
				beq $s4, 1, moveArg3ToArg2 #
				# Only executes if arg needs to be pulled from stack
					add $t1, $sp, $s0	# Set address to load from to be the previous stack frame (changed later); Make sure $s0 is positive
					sll $t2, $s3, 2	# 4 * number of total format arguments to get byte size for address
					add $t1, $t1, $t2
					sll $t2, $s4, 2	# 4 * index of current format argument to get byte size for address
					add $t1, $t1, $t2
					lw $a2, -4($t1)	# -4 needed?
					j L
				moveArg3ToArg2:
					move $a2, $a3
		
		L:
		sw $t0, 16($sp)
		beq $t0, '%', formatArgs
		#Put char into outbuf	#Only runs if not '%'
			lb $t0, ($s2)	#Load char from format
			sb $t0, ($s1)	#Put char into outbuf
			addi $s1, $s1, 1	#Increment outbufCharPtr
			j findPercentageSignsLoop
			
		back:	#Where format returns to
			lw $a0, 4($sp)	#Restore $a0
			lw $a1, 8($sp)	#Restore $a1
			lw $a2, 12($sp) #Restore $a2
			lw $t0, 16($sp)
			#INSERT: Set formatCharPtr to the right address (handle in format?)
			bne $t0, 0, findPercentageSignsLoop	#Loop
			j fin	#Only runs if current char is null terminator

	formatArgs:	#(*outbuf, *format, *formatSub)
		addi $s4, $s4, 1
		lb $t1, 1($s2)
		addi $s2, $s2, 2
		la $ra, back
		#Load arguments here:
		beq $t1, 'u', udec
		beq $t1, 'x', uhex
		beq $t1, 'o', uoct
		#INSERT: str and dec

	fin:
		#Count buffer length (make sure $a0 is still its original value)
		li $v0, 0 #Redundant?
		lw $a0, 4($sp)
		findBufferLengthLoop:
			lb $t0, ($a0)
			addi $a0, $a0, 1 #Make sure to restore $a0 if needed later
			addi $v0, $v0, 1 #Increment the return value: outbuf.length
			bne $t0, 0, findBufferLengthLoop
			subi $v0, $v0, 1 #Should compensate the value of outbuf.length correctly
		#Null terminate outbuf (outbufCharPtr should point to the last character)
			addi $s1, $s1, 1
			sb $0, ($s1)
		#Epilogue
			lw $ra, 0($sp)
			add $sp, $sp, $s0	#INSERT: stack size
			jr $ra		#this sprintf implementation rocks!

udec:	
	addi	$sp,$sp,-8	# get 2 words of stack
	sw	$ra,0($sp)	# store return address
	remu	$t0,$a2,10	# $t0 <- $a0 % 10
	addi	$t0,$t0,'0'	# $t0 += '0' ($t0 is now a digit character)
	divu	$a2,$a2,10	# $a0 /= 10
	beqz	$a2,onedig	# if( $a0 != 0 ) { 
	sw	$t0,4($sp)	#   save $t0 on our stack
	jal	udec		#   putint() (putint will deliberately use and modify $a0)
	lw	$t0,4($sp)	#   restore $t0
		                # } 

		
uhex:
	addi	$sp,$sp,-8	# get 2 words of stack
	sw	$ra,0($sp)	# store return address
	remu	$t0,$a2,16	# $t0 <- $a0 % 10
	addi	$t0,$t0,'0'	# $t0 += '0' ($t0 is now a digit character)
	divu	$a2,$a2,16	# $a0 /= 10
	beqz	$a2,onedig	# if( $a0 != 0 ) { 
	sw	$t0,4($sp)	#   save $t0 on our stack
	jal	uhex		#   putint() (putint will deliberately use and modify $a0)
	lw	$t0,4($sp)	#   restore $t0
		                # } 
	
uoct:
	addi	$sp,$sp,-8	# get 2 words of stack
	sw	$ra,0($sp)	# store return address
	remu	$t0,$a2,8	# $t0 <- $a0 % 10
	addi	$t0,$t0,'0'	# $t0 += '0' ($t0 is now a digit character)
	divu	$a2,$a2,8	# $a0 /= 10
	beqz	$a2,onedig	# if( $a0 != 0 ) { 
	sw	$t0,4($sp)	#   save $t0 on our stack
	jal	uoct		#   putint() (putint will deliberately use and modify $a0)
	lw	$t0,4($sp)	#   restore $t0
		                # } 

onedig:	
	sb $t0, ($a0)		# $a0 is outbufCharPtr; Save to outbuf
	addi $a0, $a0, 1 	# $a0 is outbufCharPtr; Increment outbuf pointer
	lw	$ra,0($sp)	# restore return address
	addi	$sp,$sp, 8	# restore stack
	jr	$ra		# return

str: #$a0 min $a1 max
	jr $ra
	
dec: #$a0 min $a1 max $a2 flag
	jr $ra
