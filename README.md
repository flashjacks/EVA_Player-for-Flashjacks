# EVA_Player for Flashjacks
 Eva Player for Flashjacks version

First:

sjasm.exe EVAFJ10.asm EVAFJ.COM


Sources:

https://retromsx.com


EVA video viewer “EVAFJ.COM”

This program allows us to view EVA videos from Flashjacks.

It is a converted program, debugged and adapted from the original program that existed for Sunrise systems.

The command would be the following:

EVAFJ VIDEO.EVA /[options]


Options are optional and works automatically without them.

If we do not put a file name, we will get the help screen.

The help screen appears very well explained but basically it is about forced options.

As for the videos, there are two types. Videos at 10FPS and 12FPS. 

The 10FPS ones do better than the 12FPS ones since the latter push the Z80 to the limit and therefore reading pauses are noted on some SD cards.

Videos can be recorded on "screen 8" or "screen 12". 

They will be played back as recorded. 

The system does not convert them. 

If they look bad in "screen 8" we should just force the screen with the "/8".

Normally the videos are on "screen 12" so if we do not have the VDP of an MSX2 + or higher, we will see these in false color.

Finally, comment that this is a software-based system and that Flashjacks helps you by providing you with the video data, the clocks, the audio channel, etc.

By this I mean that the miracle is entirely done by the Z80.

It seems incredible to be able to watch videos with audio on a CPU from the 80s.
