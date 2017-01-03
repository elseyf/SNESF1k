bass		:= "../bass/_bass.exe"
_date		:= $(subst _ ,_0,$(shell cmd /C echo %date:~0,2%_%date:~3,2%_%date:~6,4%_%time:~0,2%_%time:~3,2%_%time:~6,2%))
rom_name	:= snesf1k

normal:
	del $(rom_name)*.sfc
	del $(rom_name)*.sym
	$(bass) -sym $(rom_name).sym -create $(rom_name).asm
	rename $(rom_name).sfc $(rom_name)_$(_date).sfc
	rename $(rom_name).sym $(rom_name)_$(_date).sym
	