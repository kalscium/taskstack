# taskstack
---
> A distraction-free minimalist stack-based task management CLI that [GETS IT DONE](https://medium.com/@bre/the-cult-of-done-manifesto-724ca1c2ff13).

## Installation
---
## Compiling Locally
- Install a zig toolchain (obviously)
- Install git
- Clone the git repo
  ```sh
  git clone https://github.com/kalscium/taskstack.git
  ```
- Compile the project (optimization options are `Safe`, `Fast` & `Small`)
  ```sh
  zig build -DOptimize=ReleaseSafe
  ```
- The compiled binary should be in `zig-out/bin`
- Add the binary to your path and viola, it works.
## Downloading a Pre-Compiled Binary
- Open the releases tab on this github repo
- Find the latest release
- Download the corresponding binary for your system (`exe` for windows, `x86` or `arm`, etc)
- Add the binary to your path and viola, again, it just works.

# Getting Started / Gist of the design philosophy
---
> A list of all the 'commands' this cli has can be found through
> running
> ```sh
> taskstack --help
> ```
The main concept that this entire task management-cli is based upon is
the concept of a stack; a data-structure where items can be 'pushed'
onto the stack (at the end of the stack) and also 'popped' off the
stack (also at the end of the stack). This means that the first item to
be pushed onto the stack, is actually the last one to be popped off of
it. The order of the stack is also static/unchanging, so you cannot
complete tasks at random.

This program has two 'stacks', one for short-term tasks and one for
long-term tasks, each having their own copy of a command with it's
respective command prefix ('s' for short-term) ('l' for long-term).
For example, `slist` would list short-term tasks while `llist` would
list long-term tasks.

These design decisions were made due to them A, making the process of
programming this app incredibly simple and optimized, and also B, it
forces you to actually **GET IT DONE**. Due to the stack based
organization, it forces you to acknowledge the fact that you are
visually piling on extra tasks, and this, alongside the fact that you
cannot decide the order in which do the tasks, it forces you to
actually **get the task done**, or **be done with it** instead of
just procrastinating.

Or in other words, it forces you to take initiative, and either, get
the it *done*, or rid yourself of the task and move on, to be *done*
with it, both of which are okay. What isn't okay, is procrastinating it
and telling yourself that you'll do it, *but later*.

This program is also designed to be devoid of features, of fancy
distracting effects or bloat. It's primary purpose is to be a
dead-simple stack-based task management app and nothing more.
This is so the task management itself doesn't become a task nor a
distraction, it's meant to be frictionless and get the job **done**.

## Stack Overflows
The afformentioned stacks are actually just two staticly-sized 512
`.tsk` files in this program's 'home' directory (`~/.taskstack`).
This comes with the obvious question of "what if I try to store more
tasks than 512 bytes can hold?", and the answer to which, is a
stack-overflow, and though this can be simply fixed with dynamically
sized files, it won't be, as this is a **deliberate** design feature.

If you overflow the stack, the program won't cause any data-corruption
whatsoever. It will just simply inform you and also give you a quote
from the done manifesto. Recovering from a stack overflow is also
incredibly simple; just complete or be done with the tasks on the stack
and pop them off to make room for more tasks. Having a stack-overflow
forces you to get tasks done before you can add new ones, and prevents
you from just piling on more and more tasks.
