#
# CMPUT 229 Public Materials License
# Version 1.0
#
# Copyright 2021 University of Alberta
# Copyright 2012 Taylor Lloyd
# Copyright 2021 Danila Seliayeu
#
# This software is distributed to students in the course
# CMPUT 229 - Computer Organization and Architecture I at the University of
# Alberta, Canada.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the disclaimer below in the documentation
#    and/or other materials provided with the distribution.
#
# 2. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
#-------------------------------------------------------------------------------------------------------------------------

.data
# main-specific memory addresses
binary:		.space 2048
noFileStr:	.asciz "Couldn't open specified file.\n"
# parseARM-specific memory addresses
andStr: .asciz "AND"
orStr: .asciz "OR"
addStr: .asciz "ADD"
subStr: .asciz "SUB"
lslStr: .asciz "LSL"
asrStr: .asciz "ASR"
lsrStr: .asciz "LSR"
rorStr: .asciz "ROR"
cmpStr: .asciz "CMP"
bxStr: .asciz "BX"
bStr: .asciz "B"
balStr: .asciz "BAL"
unkStr: .asciz "???"

eqStr: .asciz "EQ "
geStr: .asciz "GE "
gtStr: .asciz "GT "
blankStr: .asciz " "
rStr: .asciz "R"
sStr: .asciz "S "
arStr: .asciz " AR "
lrStr: .asciz " LR "
llStr: .asciz " LL "

sepStr: .asciz ", "

nlStr: .asciz "\n"

#-------------------------------------------------------------------------------------------------------------------------
# ARM Parser
# Author: Taylor Lloyd
# Date: July 4, 2012
# Cleanliness edits and translation into RISC-V: Danila Seliayeu
# Date: June 14, 2021
#-------------------------------------------------------------------------------------------------------------------------

.text
main:
	lw	a0, 0(a1)				# put the filename pointer into $a0
	li	a1, 0					# set read only flag
	li	a7, 1024				# open file
	ecall
	bltz	a0, main_err				# open failed if negative

   	# write file with descriptor in a0 into binary space 
    	la      a1, binary
    	li      a2, 2048				# read a file of at max 2kb
    	li      a7, 63		
	ecall						# write and save # bytes written into a0

	# save relevant registers into stack pointer
	addi	sp, sp, -12
	sw	ra, 0(sp)
	sw	s0, 4(sp)
	sw	s1, 8(sp)

	la	s0, binary 				# s0 <- pointer to current instruction
	add	s1, s0, a0				# s1 <- pointer to space after last instruction
	main_parseLoop:
		bge	s0, s1, main_done		# jump to main_done if parsed all instructions
		lw	a0, 0(s0)			# load the word to parse

		jal	ra, parseARM
		
		addi	s0, s0, 4
		
		j	main_parseLoop
	main_err:
		la	a7, noFileStr
		li	a7, 4
		ecall
	main_done:
		lw	s1, 8(sp)	
		lw	s0, 4(sp)
		lw	ra, 0(sp)
		addi	sp, sp, 12
		
		li	a7, 10
		ecall					# end program


#-------------------------------------------------------------------------------------------------------------------------
# parseARM
# This function parses binary representation of a single binary ARM instructions and prints its text correspondent.
#
# Arguments: 
#   - a0: ARM instruction to be printed.
# Register Usage:
#   - s0: ARM instruction.
#   - s1: 0 if current instruction is data processing, 1 if branch, 2 if branch and exchange, -1 if invalid.
#-------------------------------------------------------------------------------------------------------------------------
parseARM:
	addi	sp, sp, -12
	sw	ra, 0(sp)
	sw	s0, 4(sp)
	sw	s1, 8(sp)
	
	mv	s0, a0
	jal	ra, parseType
	mv	s1, a0	
	mv	a0, s0
	jal	ra, parseCondition

	beqz	s1, parseARM_dataProc
	li	t0, 2
	beq	s1, t0, parseARM_branch
	j	parseARM_BX

	parseARM_dataProc:
		li	t0, 0x00100000
		and	t0, t0, s0			# mask out status bit
		beqz	t0, parseARM_dataProc_noStat 
		# has status register 1 so print it
		la	a0, sStr
		li	a7, 4
		ecall
		
		parseARM_dataProc_noStat:
			# if CMP instruction then don't print dest since it has no dest. register
			slli	t0, s0, 7
			srli	t0, t0, 28		# t0 <- instruction opcode
			li	t1, 0x0A		# t1 <- CMP opcode
			beq	t0, t1, parseARM_dataProc_noDest

			slli	t0, s0, 16
			srli	t0, t0, 28		#isolate dest. register
	
			mv	a0, t0
			li	a1, 1
			jal	ra, printRegister
	
		parseARM_dataProc_noDest:
			# if shift instruction don't print operand1 since it's not used
			slli	t0, s0, 7
			srli	t0, t0, 28		# t0 <- instruction opcode
			li	t1, 0x0D		# t1 <- shift instruction opcode
			beq	t0, t1, parseARM_dataProc_noOp1

			slli	t0, s0, 12
			srli	t0, t0, 28		#isolate operand 1
	
			mv	a0, t0
			li	a1, 1
			jal	ra, printRegister

		parseARM_dataProc_noOp1:
			li	t0, 0x02000000		# mask out immediate indicator
			and	t0, t0, s0
	
			# print immediate if there is one, otherwise print register
			bnez	t0, parseARM_dataProc_imm
			j	parseARM_dataProc_reg

		parseARM_dataProc_imm:
			andi	t0, s0, 0x00FF		# isolate immediate value
			srli	t1, s0, 8	
			andi	t1, t1, 0x0F		# get rotation value
			slli	t1, t1, 1		# double it
			# rotate the immediate to the right (i.e. shift with wraparound)
			srl	a0, t0, t1
			li	t4, 32
			sub	t4, t4, t1
			sll	t4, t0, t4
			or	a0, a0, t4
		
			li	a7, 1
			ecall
			j	parseARM_done

		parseARM_dataProc_reg:
			andi	a0, s0, 0x0F		# mask out last register
			# check if shift immediate is 0: if it is, set a1 to 0
			slli	t0, s0, 20		
			srli	t0, t0, 27		# isolate shift amount
			sgtz	a1, t0			# if shamt > 0 then a1 is 1, 0 otherwise
			# figure out status of bit 4 indicating whether register or immediate shift 
			srli	t1, s0, 4	
			andi	t1, t1, 1
			or	a1, a1, t1		# now if a1 = 0, sepStr shouldn't be included and vice versa for 1		
			# if non shift continue
			slli	t0, s0, 7
			srli	t0, t0, 28
			li	t1, 0x0D
			bne	t0, t1, parseARM_dataProc_reg_cont
			# override a1 to be 1 no matter what
			li	a1, 1
		parseARM_dataProc_reg_cont:
			jal	ra, printRegister
			mv	a0, s0
			jal	ra, parseShift
			
			j	parseARM_done

	parseARM_branch:
		li	t0, 0x00FFFFFF			# mask lower 24 bits
		and	t0, t0, s0			# branch offset

		slli	t0, t0, 8
		srai	a0, t0, 6			# sign extend,

		li	a7, 1
		ecall					# print the branch offset

		j	parseARM_done
		
	parseARM_BX:
		andi	a0, s0, 0x0F			# isolate the register
		li	a1, 0
		jal	ra, printRegister
		# continue to parseARM_done
	parseARM_done:
		la	a0, nlStr
		li	a7, 4
		ecall
	
		lw	ra, 0(sp)
		lw	s0, 4(sp)
		lw	s1, 8(sp)
		addi	sp, sp, 12

		ret

#-------------------------------------------------------------------------------------------------------------------------
# parseShift
# This function parses and prints shift type and value of ARM data-processing register instructions that aren't
# LSL/LSR/ASR.
#
# Arguments: 
#   - a0: ARM instruction with type to be parsed and printed.
# Register Usage:
#   - t2: used to hold aforementioned ARM instruction while a0 register is used for ecalls.
#-------------------------------------------------------------------------------------------------------------------------
parseShift:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	mv	t2, a0	
	
	# if shift instruction then don't go to parseShift_shift because shift type has already been written
	slli	t0, a0, 7
	srli	t0, t0, 28
	li	t1, 0x0D
	beq	t0, t1, parseShift_shift
	
	slli	t0, a0, 25				# parse shift type
	srli	t0, a0, 30

	# LL
	li	t1, 0x00		
	la	a0, llStr
	beq	t0, t1, parseShift_check

	# LR
	li	t1, 0x01
	la	a0, lrStr
	beq	t0, t1, parseShift_check

	# AR
	li	t1, 0x02			
	la	a0, arStr
	beq	t0, t1, parseShift_check
	
	# ROR
	li	t1, 0x03
	la	a0, rorStr
	beq	t0, t1 parseShift_check

	la	a0, unkStr	
	
	j parseShift_check
	
	parseShift_shift:
		# skip printing rot. type if shift instruction
		andi	t0, t2, 0x0010			# isolate reg(1)/imm(0) bit
		bnez	t0, parseShift_printReg	
		j	parseShift_printImm
	parseShift_check:
		# don't print if we're shifting 0
		andi	t0, t2, 0x0010			# isolate reg(1)/imm(0) bit
		bnez	t0, parseShift_printRot		# always print if register
		slli	t0, t2, 20			# isolate shift amount
		srli	t0, t0, 27
		beqz	t0, parseShift_done

	parseShift_printRot:
		# print rotation type
		li	a7, 4		
		ecall
		
		andi	t0, t2, 0x0010			# isolate reg(1)/imm(0) bit
		bnez	t0, parseShift_printReg

	parseShift_printImm:
		slli	t0, t2, 20			# isolate shift amount
		srli	a0, t0, 27

		li	a7, 1
		ecall

		j	parseShift_done

	parseShift_printReg:
		# isolate shift register	
		slli	t0, t2, 20	
		srli	a0, t0, 28
		li	a1, 0
		jal	ra, printRegister

		j	parseShift_done
	
	parseShift_done:
		lw	ra, 0(sp)		
		addi	sp, sp, 4
		
		ret	

#-------------------------------------------------------------------------------------------------------------------------
# parseType
# This function prints the instruction type, which here means AND, OR, branch, etc.
#
# Arguments: 
#   - a0: ARM instruction with type to be parsed and printed.
# Returns:
#   - a0: 0 if printed current instruction is data processing or invalid, 1 if branch and exchange, 2 if branch.
# Register Usage:
#   - t4: temporary placeholder for a0 that will be returned.
#-------------------------------------------------------------------------------------------------------------------------
parseType:
	# check whether instruction is unconditional branch
	li	t4, 2					# assume branch and exchange

	slli	t0, a0, 4				
	srli	t0, t0, 28				# isolate bits 27-24

	la	t3, bStr
	li	t1, 0x0A				# t1 <- bits 27-24 unique to a branch instruction
	beq	t0, t1, parseType_done
	
	# print instructions, choosing based on data-proccessing opcode (bits 24-21)
	slli	t0, a0, 7
	srli	t0, t0, 28				# t0 <- opcode

	li	t4, 0					# assume current instruction is data-proc
	
	la	t3, andStr
	li	t1, 0x00
	beq	t0, t1, parseType_done
	
	# OR
	la	t3, orStr
	li	t1, 0x0C
	beq	t0, t1, parseType_done

	# ADD
	la	t3, addStr
	li	t1, 0x04
	beq	t0, t1, parseType_done

	# SUB
	la	t3, subStr
	li	t1, 0x02
	beq	t0, t1, parseType_done

	# MOV
	li	t1, 0x0D
	beq	t0, t1, parseType_shift


	# instruction could still be a BX instruction: check to see 
	li	t4, 1

	# BX
	la	t3, bxStr
	li 	t2, 0x0FFFFFF0
	and 	t2, a0, t2
	li 	t1, 0x012FFF10
	beq	t2, t1, parseType_done

	# CMP
	# make sure register Rd is 0
	srli 	t1, a0, 12
	andi	t1, t1, 0x000F
	bnez	t1, parseType_unknown
	la	t3, cmpStr
	li	t1, 0x0A
	beq	t0, t1, parseType_done

    	j   parseType_unknown

    	parseType_shift:
    		# check to see whether or not bits 19-16 are 0 first
    		slli 	t0, a0, 12
    		srli	t0, t0, 28
    		bnez	t0, parseType_unknown
    	
		slli	t0, a0, 25			# isolate shift type
		srli	t0, t0, 30

		li	t1, 0x00			# logical left
		la	t3, lslStr
		beq	t0, t1, parseType_done

		li	t1, 0x01			# logical right
		la	t3, lsrStr
		beq	t0, t1, parseType_done

		li	t1, 0x02			# arithmetic right
		la	t3, asrStr
		beq	t0, t1, parseType_done

		li	t1, 0x03			# rotate right
		la	t3, rorStr
		beq	t0, t1 parseType_done

    	parseType_unknown:
	    	li	t4, 0	
	    	la	t3, unkStr

	parseType_done:
		mv	a0, t3
		li	a7, 4
		ecall
		
		mv	a0, t4
		
		ret

#-------------------------------------------------------------------------------------------------------------------------
# printRegister
# This function prints regiser passed in a0 with a space following it.
#
# Arguments: 
#   - a0: register to be printed.
#   - a1: 1 if sepStr should be printed, 0 if not.
# Register Usage:
#   - t0: used to hold original a0 value while the register is used for printing.
#-------------------------------------------------------------------------------------------------------------------------		
printRegister:
	mv	t0, a0
	
	la	a0, rStr
	li	a7, 4
	ecall

	mv	a0, t0
	li	a7, 1
	ecall						# print register
	
	beqz	a1, printRegister_done			# skip separator 
	
	la	a0, sepStr
	li	a7, 4
	ecall						# space for next
	
	printRegister_done:
		ret

#-------------------------------------------------------------------------------------------------------------------------
# parseCondition
# This function parses and prints the condition of the ARM instruction passed in a0.
#
# Arguments: 
#   - a0: ARM instruction with condition to be parsed and printed.
# Register Usage:
#   - t3: used to hold address of 
#-------------------------------------------------------------------------------------------------------------------------	
parseCondition:
	srli	t0, a0, 28				# t0 <- condition bits

	# unconditional
	la	t3, blankStr
	li	t1, 0x0E
	beq	t0, t1, parseCondition_done

	# on equals
	la	t3, eqStr
	li	t1, 0x00
	beq	t0, t1, parseCondition_done

	# on greater than
	la	t3, gtStr
	li	t1, 0x0C
	beq	t0, t1, parseCondition_done

	# on greater than or equals
	la	t3, geStr
	li	t1, 0x0A
	beq	t0, t1, parseCondition_done

	# unkown condition
	la	t3, unkStr

	parseCondition_done:
		mv	a0, t3
		li	a7, 4
		ecall
		ret
