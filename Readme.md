
## Tart
Tart is a game engine with a heavy focus on multithreading, modularity and efficiency and written in Nim.

### How to use
To build the project just make sure that Nim and Nimble (it's package manager)
are properly installed.

Then build the project:

```nim build project```

And execute it with:

```./project```

Both can be done at the same time with the command:

```nim run project````

### Multithreading
Most of today's games are made to work on a number of threads (generally 4 on computers),
while leaving other threads pretty much unused. However, the future seems to point that
more power (and possible more efficiency) will only come with more threads rather than
faster threads. This reasoning makes us think that there's a need for a game engine with
a highly parallel game engine.

The way this is done in Tart is by creating working threads and the data is treated
by jobs which are called in a event-driven fashion in any thread.

### Modularity
Not two projects are equal and having the ability to swap any (non-core) component
at any moment is very important, not only so that a same project can adapt to
diferent interfaces, also makes it posible to swap some critic modules
( like the graphical ones ) for a version optimized out for the specific
application.

Also this huge modularity means that Tart is able to fulfill any purpose, as
functionality can added and removed easily, making it an excellent tool to
build open it.

### Eficiency
This is an aspect of games which feels forgotten in games more often than not,
up to the point where some games need computers way more powerful for their
execution than they ought to.

Note: When talking about efficiency, we mean general efficiency, of course,
but take in mind that here efficiency is highly related to CPU efficiency.

This is actually a very important matter, as a very efficient engine let us
implement more optimization techniques on other fronts like on GPU or disk, or
let the game developer worry less on it's game perfomance (but by no means
ignoring it) or just reduce the cycles needed making it usable on less powerful
platforms (helping universal availability) or even just use less energy (
very interesting on portable devices so that the battery lasts longer, and on
any platform because of helping event if it's a little the environment).

For such thing as a platform, efficiency does not just stop with being efficient
by itself, but rather to help the user develop more efficient programs.

The sidefect of this focus on efficiency is a reduction on the easy to use
factor, fortunately changing our programing language makes us capable of
countering this.

### Nim
While most people just stays on what is most used today, however, there's an
important and (sort of phylosophical ) question which is mostly unanswered
today: Can we do this any better? This is interisting since so much source code
is made today even the tiniest improvement could save a lot of time. That's why
is interesting in investing time in new languages.

After a lot of research for languages for constructing new programs I arrived at
Nim, which has two main selling points: to give a feeling of a scripted language
while being fully compiled, and have powerful metaprogramming capabilities,
this is because Nim's goal is stated to be expressive and efficient, and it 
really lives up to that, as has a clean syntax resembling Python's and it's
performance it's pretty much that of C ( after all is compiled to it).

Nim's metaprogramming and script-like capabilities makes it easy to hide
implementation complexities, while this has yet to fully realize, we believe
that we will be able to help people to code faster games in less time. 

