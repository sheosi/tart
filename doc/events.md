# Events
One main point of Tart are events. Events are a way of decoupling parts which though coupled together don't have much dependency and just want to be aware of something happening: like whether the window has received input, the threads have been initiated or it's time to render another frame. Here we will describe Tart's signals.

NOTE: Events names of signals are case insensitive while using tart's functions, because we convert them to lowercase.

## Main Init

## Thread Init
This event marks that a thread is being initiated, at startup time it's the first thing that's called and it's called for every single thread, but just once. This event is where initialization code which should be called per thread (maybe because of separate memory) sould be put.

## Game Init
This is called right after every thread init is called and start the initiation sequence of the game. The main use case for this event is for calling initialization cade of base libraries.

## Allegro Init (Implementation specific)
The current implementation of Tart is using Allegro as backend library for pretty much everything: fonts, audio, window handling ,graphics ... This event is called right now after Game Start finishes because there are some things that must be done to initialize allegro while keeping it in a modular way.

As this is used with Allegro-related code Allegro Init is implementation specific, so it will change if it does the underlying implementation.

## Game Start
After everything has been initialized, the game starts, and Game Start marks this.

## Frame Render
Because of how computers work and because games are dynamic from time to time we must redraw everything in the screen on their new positions, also some things must be recalculated and some events processed(like speed and acceleration).

## Game End (TODO)
