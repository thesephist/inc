# Inc(remental) 📌

**inc** is an [incremental note-taking system](https://thesephist.com/posts/inc/) — it's an experimental, append-only notes app for growing a knowledge base by incrementally adding quick, lightweight notes to a database of ideas rather than managing a complex collection of documents that change arbitrarily. I use Inc to manage the development of Inc itself, using the `inc.db.json` database in this repository. You can read more about that at the end of the README.

Here's an example interactive session using the Inc CLI.

```c
$ inc
> ls
(no results)
> + My first note #test
> + My second note #test
> You can also add notes without the "+" #protip
> ls
  0 You can also add notes without the "+" #protip now
  1 My second note #test now
  2 My first note #test now
> + Remove notes with "rm"
> rm 1-2
> ls
  0 Remove notes with "rm" now
  1 You can also add notes without the "+" #protip now
>
>
> Here I am, adding a \
> multi-line note, composed of many \
> lines connected with \ characters.
> ls
  0 Here I am, adding a multi-line note, composed of many lines
    connected with \ characters. now
  1 Remove notes with "rm" now
  2 You can also add notes without the "+" #protip now
> @0 #protip #test
> ls
  0 Here I am, adding a multi-line note, composed of many lines
    connected with \ characters. #protip #test now
  1 Remove notes with "rm" now
  2 You can also add notes without the "+" #protip now
```

Inc, like most of my side projects, is built with the [Ink programming language](https://dotink.co/). Inc has no other dependencies at the moment. (Yes, Inc is built with Ink. Naming is hard. I don't know.)

## Incremental note-taking

[Incremental note-taking](https://thesephist.com/posts/inc/) is a set of principles I've coined for building a notes app that truly extends your memory. These principles are:

>1. **Captured ideas are better than missed ones.** No self-respecting “note-taking system” should ever allow an idea to escape our minds un-recorded because it took too long, or was too much of a hassle to write it down.
>2. **Adding new ideas are better than changing old ideas.** When we learn something new, what we learned before doesn’t suddenly change, we have simply learned something new. [...] Just as our memory grows by remember new things rather than “updating” old memories, our notes should also grow by incrementally gaining new knowledge, rather than replacing old valuable ideas with more recent ones.
>3. **Ideas that can’t be recalled are worse than useless** – effective search is the soul of great notes. [...] A great note-taking system should make it trivial to get ideas out, as well as in.
>4. **Time is essential to how we remember,** and should be a first-class citizen of our note-taking system. When we learned something isn’t merely arbitrary metadata about some knowledge, but a mental anchor we use to remember nearly everything.

Inc is an experiment to see how austere a manifestation of these ideas could be, while still being functional, useful, and ergonomic. As a result, Inc doesn't act like a traditional note-taking app, where you create notes for each topic and update a note whenever you learn something new. Instead, it acts a lot more like a "log" (as in, for example, a database log), because inc is an **append-only** notes app. When you want to update your notes, you can only add new entries or add to existing entries; you can't delete old notes.

This might seem strange at first -- how do you update outdated information when you can't delete them from your notebook? The answer is that with incremental notes, a note is less a record of what something is today, and more a _log_ of all the thoughts I've had about something. It turns out that keeping notes this way has lots of nice properties, like having an implicit "edit history" of your ideas.

Lastly, Inc as it is today isn't meant to be the best implementation of incremental note-taking or a complete, user-friendly package. It's an experimental project for me to try to use so I can discover interesting workflows or see errors in my hypotheses. Hopefully, with time and learnings, Inc will change dramatically.

## Usage

Inc currently only works as a command-line interactive REPL. With [Ink](https://dotink.co) installed, run `./src/main.ink` (which I've aliased to `inc` in my setup) to get the REPL prompt.

```
$ ./src/main.ink
>
```

As seem at the top of the README, this REPL is the main way to interact with Inc. We can type in commands, and Inc will execute them. For example, typing `ls` shows us all the notes we have in the database (in this case, nothing).

```
> ls
(no results)
```

Add a note by simply typing your note. If your note might be misinterpreted as a command (lines beginning with `#` or `/` have special meaning, for example) we can use the `+` command to tell Inc that we're trying to add a note.

```
> This is a note I just added
> + This is another note I wrote!
> ls
  0 This is another note I wrote! now
  1 This is a note I just added now
```

We can append to an existing note at this point, by targeting a note using its number (for example, `1` from above) and typing more text.

```
> @1 #important!
> ls
  0 This is a note I just added #important! now
  1 This is another note I wrote! 1m
```

Another important action is _search_. We can search our notes for a substring by typing `/search query`. If we're searching for a hashtag, we can simply type the hashtag we want. In other words, `/#todo` and `#todo` commands are equivalent.

```
> /important
  0 This is a note I just added #important! 1m
> /another
  0 This is another note I wrote! 3m
```

These are the bare-basics of taking and searching notes with Inc. There are a few more useful commands you'll use on occasion:

- `show N` to show the full-length version of a note from a list, if that note is too long to be displayed in full in a list. `show` takes multiple arguments, so writing `show 1-4` and `show 1 2 3 4` will both show notes 1, 2, 3, and 4.
- `history` prints out your REPL history with normalized formatting.
- `meta` will show some aggregate statistics about your notes, along with the location of the current Inc notes database file.
	```
	> meta
	DB path: /tmp/inc.db.json
	Stats: 2 notes, 8 events
	```

## Setup and installation

In all honestly, you probably won't get much out of installing Inc. It's mostly a personal prototype and experiment at this point, and it's quite buggy and might lose your data. That said... if you must try it:

Inc is an Ink program that runs in your terminal. You can install the Ink programming language by following the [instructions on the Ink website](https://dotink.co/docs/overview/#setup-and-installation), and then clone this repository.

Then ensure Ink is in your path, and run `./src/main.ink` to start the Inc REPL.

```
$ ./src/main.ink
>
```

By default, Inc should create a file called `inc.db.json` in your home directory and use it to store your notes. If you'd like to move the file elsewhere, set the `INC_DB_PATH` environment variable to point to the directory at which you'd like the file to exist. By default, it's assumed to be `$HOME` in your environment.

## Inc, managed with Inc

Future roadmap items, project ideas, and other random development tasks are tracked within the project using Inc itself, in the `inc.db.json` database in the repository.

For todos and future roadmap ideas, see this database, which you can do using the `INC_DB_PATH` environment variable.

```
# from the repository root directory
$ INC_DB_PATH=. inc ls
[...]
```

Generally, bugs and features are tagged `#todo` and general future roadmap ideas are tagged `#idea`. The four principles of incremental notes are also in this database, tagged `#principle`.

