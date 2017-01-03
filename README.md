# SNESF1k
Brainf*ck Interpreter for Super NES in just 1kByte of Memory

The ready to use .sfc ROM is running on no$sns v1.6 and bsnes-plus v073+3. It should run on flash cartridges too, but they may not be able to determine the ROM Size and Mapping if they require a proper Header. The SNES does not care for that Header, so the ROM can be executed on a real system too without issues (assuming you can burn an EPROM and wire it to mirror the 1kB program across the whole LOROM Mapping scheme).

Assembled with bass (https://github.com/ARM9/bass)
