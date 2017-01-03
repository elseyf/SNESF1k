putchar:
//If "Null Terminator", Z Flag is set
	bne no_null_terminator
	//return if NULL terminator was read:
		rts
	no_null_terminator:
	//Check if lowercase letter:
		cmp #$61//lower 'a'
		bcc no_lowercase
		cmp #$7B//greater 'z'
		bcs no_lowercase
		//Get Uppercase by substracting $20:
			sec;sbc #$20
	//Tabulator is converted to space:
	no_lowercase:
		cmp #$09
		bne no_tabulator
			lda.b #' '
	no_tabulator:
	//check if Newline:
		cmp #$0A
		bne no_newline
		//Newline: goto next Line
		dec.b x_counter
		beq printf_goto_next_line
			ld_text_from_base_newline_loop:
				//Put space char for rest of line
					lda.b #' '
				//Write Char to Buffer:
					jsr write_char_to_buffer
					dec.b x_counter
					bne ld_text_from_base_newline_loop
				//Reload Counter:
					lda #$20
					sta.b x_counter
	no_newline:
	//Write Char to Buffer:
		jsr write_char_to_buffer
	//Decrease Counter, if zero, reset:
		dec.b x_counter
		bne rts_putchar
		printf_goto_next_line:
			//Reload Counter:
				lda #$20
				sta.b x_counter
		
//-------------------------------------------//
rts_putchar:
rts

write_char_to_buffer:
//Write Char to Buffer:
rep #$20//A 16-Bit
	and #$00FF
	sta [char_out_buffer_addr]
	inc.b char_out_buffer_addr
	inc.b char_out_buffer_addr
	//Check if $03C0 chars were written
	lda.b char_out_buffer_addr
	and #$07FF
	cmp #$0780
	//When greater or equal, carry is set:
	bcc write_char_to_buffer_no_reload_addr
		lda #$7800
		sta.b char_out_buffer_addr
	write_char_to_buffer_no_reload_addr:
sep #$20//A 8-Bit
rts
