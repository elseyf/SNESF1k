//SNESF1k by el_seyf
//Brainf*k Interpreter for Super NES/Famicom
arch snes.cpu					//assemble to be a SNES executeable
output	"snesf1k.sfc", create	//specifies output name,
								//will overwrite existing file
//*******************************************************************//
//DEFINES:
//Define Controller Registers:
define CTRL1($4218)
define CTRL2($421A)
//Controller Button Mask:
define  RIGHT_KEY(#$0100)
define   LEFT_KEY(#$0200)
define   DOWN_KEY(#$0400)
define     UP_KEY(#$0800)
define  START_KEY(#$1000)
define SELECT_KEY(#$2000)
define      Y_KEY(#$4000)
define      B_KEY(#$8000)
define      R_KEY(#$0010)
define      L_KEY(#$0020)
define      X_KEY(#$0040)
define      A_KEY(#$0080)
define    ANY_KEY(#$FFF0)
//*******************************************************************//
//MACROS:
//pch() Macro used to output an Address in Hex
include "print_hex_macro.asm"
//Addressing and Banking Macro:
macro org(address) {
	variable old_pc(pc())
	origin (({address} & $7F0000) >> 1) | ({address} & $7FFF)
	base {address}
	if (pc() < old_pc) {
		evaluate p(old_pc)
		print "Old PC: $";print_hex({p});print "\n"
		print "New PC: $";print_hex({address});print "\n"
		print "Error: Overwriting assembled Memory: ",(pc()-old_pc),"\n"
		error "Cannot set PC backwards..."
	}
}
//Console Output Macros:
variable amount_of_banks(1)
macro print_free_space() {
	if (((65536*amount_of_banks)-pc()) < 0) {
		putchar(9);print "No Free Space in Bank ",amount_of_banks-1
		print " (",((65536*amount_of_banks)-pc())*(-1)," Bytes too much)\n"
		error ""
	}
	print "CODE SIZE:\n"
	putchar(9);print (pc()-$8000)+60;putchar(9);print "Bytes used\n"
	putchar(9);print ($8400-pc())-60;putchar(9);print "Bytes free\n"
	putchar(9);print ($10000*amount_of_banks)-pc();putchar(9);
	print "Bytes remain free in Bank ",amount_of_banks-1,"\n"
	amount_of_banks=amount_of_banks+1
}
//*******************************************************************//
//VARIABLES:
org($0000)
match_counter:;	db $00
x_counter:;	db $00
char_out_counter:;	db $00
char_out_buffer_addr:;	dl $000000
_pad:;	dw $0000
snesf1k_data_pointer:;	dl $0000
org($0010)
snesf1k_data:;
//*******************************************************************//
//CODE:
org($8000)
//-------------------------------------------------------//
//Demo Program, shows everything excluding input (','):
snesf1k_pgm:
db "-[>.+<]"//Outputs Byte repeatedly
//-------------------------------------------------------//
INIT:
//Set CGRAM Addr to $00:
	stz $2121
//Set Scroll to $00
	stx $210D//Write X and Y lower 8-Bit
	stx $210D//Write X and Y upper 8-Bit
//Set CGRAM Color 0 to Black:
	stz $2122
	stz $2122
//Set VRAM Addr to $0000:
	stx $2116
//Set DMA Channel 0 CPU Source HIGH Byte to $7F
	lda #$7F
	sta $4304
//Set PPU Increment on write to $2119, by 1 word
	inc//A=$80
	sta $2115
//Enable NMI and auto-read joypad:
	inc//A=$81
	sta $4200
//Set CGRAM Color 1 to green:
	sta $2122
	sta $2122
//Enable BG1:
	sta $212C
//Set Y to $0000:
	txy
//copy font to PPU and clear RAM $0000-1FFF:
	copy_font_clear_ram:
		lda.w (font_chr-$100),x
		sta $2118
		tya//A=$00
		sta $2119
		sta $00,x
		sta $7F7800,x
		inx
		cpx #$2000
		bne copy_font_clear_ram
		
//Setup DMA Channel 0 to transfer BG1MAP in WRAM to VRAM:
//Set Mode:
	inc//A=$01
	sta $4300
//Map Location:
	ldx #$7800
//Set BG1MAP to $7800
//disable Mosaic on any Screen:
	stx $2106//Write $00 to $2106 and $78 to $2107
	stx.b char_out_buffer_addr
//Set indirect addressed char_out_buffer_addr to $7F
	lda #$7F
	sta.b char_out_buffer_addr+2
//Set x_counter to $20 (32 chars per line):
	lda #$20
	sta.b x_counter
	
//Set Screen to full Brightness and disable force Blank:
	lda #$0F
	sta $2100
//Set snesf1k_data_pointer to $0010:
	inc//A=$10
	sta.b snesf1k_data_pointer
//set A and X to $0000:
	tya
	tyx
//*******************************************************************//
//SNESF1k MAIN:
//A: Instruction
//X: Data Pointer
//Y: Program Counter
//*******************************************************************//
main:
php
rep #$20//A 16-Bit
//Read input:
	lda {CTRL1}
	
	
	
	
	sta _pad
plp
	
	jsr decode_instruction
jmp main
//*******************************************************************//
font_chr:
	insert "font1bpp0.bin"//$200 Bytes
//*******************************************************************//
	include "putchar.asm"
//*******************************************************************//
decode_instruction:
//Fetch Instruction:
	lda snesf1k_pgm,y
//Decode:
	//If zero, return:
	bne decode_instruction_check_plus
		rts
	decode_instruction_check_plus:
		cmp.b #'+'
		bne decode_instruction_check_minus
		//Increase Value at Data Pointer:
			lda [snesf1k_data_pointer]
			inc
			sta [snesf1k_data_pointer]
			bra decode_instruction_check_end
			
	decode_instruction_check_minus:
		cmp.b #'-'
		bne decode_instruction_check_dp_inc
		//Decrease Value at Data Pointer:
			lda [snesf1k_data_pointer]
			dec
			sta [snesf1k_data_pointer]
			bra decode_instruction_check_end
			
	decode_instruction_check_dp_inc:
		cmp.b #'>'
		bne decode_instruction_check_dp_dec
		//Increase Data Pointer:
			ldx.b snesf1k_data_pointer
			inx
			//If Data Pointer passes beyond $1FF0, reset to $0010:
			cpx #$1FF0
			bcc decode_instruction_check_dp_inc_no_reset
				ldx #$0010
			decode_instruction_check_dp_inc_no_reset:
			stx.b snesf1k_data_pointer
			
	decode_instruction_check_dp_dec:
		cmp.b #'<'
		bne decode_instruction_check_branch_zero
		//Decrease Data Pointer:
			ldx.b snesf1k_data_pointer
			dex
			//If Data Pointer passes below $000F, reset to $1FEF:
			cpx #$0010
			bcs decode_instruction_check_dp_dec_no_reset
				ldx #$1FEF
			decode_instruction_check_dp_dec_no_reset:
			stx.b snesf1k_data_pointer
			
	decode_instruction_check_branch_zero:
		cmp.b #'['
		bne decode_instruction_check_branch_not_zero
		//Check Value at Data Pointer:
			lda [snesf1k_data_pointer]
		//If zero, branch to next matching ']':
			bne decode_instruction_check_end
			//Use X as match counter, start at 1:
				ldx #$0001
			decode_instruction_check_branch_zero_do_branch:
			//Advance Program Counter by 1:
				iny
			//Fetch new Instruction:
				lda snesf1k_pgm,y
			//If '[', increase match counter:
				cmp.b #'['
				bne decode_instruction_check_branch_zero_do_branch_check_closing
					inx
				decode_instruction_check_branch_zero_do_branch_check_closing:
			//If ']', decrease match counter, exit if zero:
				cmp.b #']'
				bne decode_instruction_check_branch_zero_do_branch
					dex
					bne decode_instruction_check_branch_zero_do_branch
			//!BRA needed, as A holds ']':
				bra decode_instruction_check_end
				
	decode_instruction_check_branch_not_zero:
		cmp.b #']'
		bne decode_instruction_check_output
		//Check Value at Data Pointer:
			lda [snesf1k_data_pointer]
		//If not zero, branch to next matching '[':
			beq decode_instruction_check_end
			//Use X as match counter, start at 1:
				ldx #$0001
			decode_instruction_check_branch_not_zero_do_branch:
			//Decrease Program Counter:
				dey
			//Fetch new Instruction:
				lda snesf1k_pgm,y
			//If ']', increase match counter:
				cmp.b #']'
				bne decode_instruction_check_branch_not_zero_do_branch_check_opening
					inx
				decode_instruction_check_branch_not_zero_do_branch_check_opening:
			//If '[', decrease match counter, exit if zero:
				cmp.b #'['
				bne decode_instruction_check_branch_not_zero_do_branch
					dex
					bne decode_instruction_check_branch_not_zero_do_branch
			
	decode_instruction_check_output:
		cmp.b #'.'
		bne decode_instruction_check_input
		//Output Value at Data Pointer to Screen:
			lda [snesf1k_data_pointer]
			jsr putchar
			
	decode_instruction_check_input:
		cmp.b #','
		bne decode_instruction_check_end
			//Do smth
			
	decode_instruction_check_end:
	//Advance Program Counter:
		iny
decode_instruction_rts:
	rts
	
//DEBUG:
	print "\nFree: ",(font_chr1-pc())," Bytes\n"
//*******************************************************************//
org(font_chr+$2D8)
font_chr1:
	insert "font1bpp1.bin"//$20 Bytes
//*******************************************************************//
print "--------------------------------------------------\n"
print_free_space()
print "--------------------------------------------------\n"
//*******************************************************************//
//*******************************************************************//
org($83C0)
//NMI can be 32 Bytes:
NMI:
phx
	//CPU Destination
		ldx #$0018
		stx $4301
	//Size of Transfer
		ldx #$0800
		stx $4305
	//Set VRAM Destination:
		ldx #$7800
		stx $2116
	//CPU Source: LOW, MIDDLE
		stx $4302
	//Start Transfer:
		ldx #$0001
		stx $420B
plx
rti
//*******************************************************************//
org($83E0)
//Reset Routine; wrapping around Interrupt Vectors:
RESET:
//Enable Interrupts:
	sei
//Set Native Mode:
	clc
	xce
//Set Register Size:
	sep #$20//A 8-Bit
	rep #$10//XY 16-Bit
//Set the Stack to $1FFF:
	ldx #$1FFF
//native Mode Vectors:
org($83EA)
//Only NMI is used:
	dw NMI//Will be executed as CPY $xx
//Transfer X to Stack:
	txs
//Set X to $0000:
	ldx #$0000
//Use BG Mode 0:
	stz $2105
//Set BG1CHR to $0000:
	stz $210B//BG1CHR Source Address
//Jump to Init Routine:
	jmp INIT
//emulation Mode Vectors:
org($83FC)
	dw	RESET
	dw  RESET//IRQ/BRK will Reset
//*******************************************************************//
org($8400)
