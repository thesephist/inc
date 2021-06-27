#!/usr/bin/env ink

std := load('../vendor/std')
str := load('../vendor/str')
quicksort := load('../vendor/quicksort')
json := load('../vendor/json')
ansi := load('../vendor/ansi')
util := load('util')
markup := load('markup')
command := load('command')

log := std.log
f := std.format
range := std.range
scan := std.scan
slice := std.slice
cat := std.cat
map := std.map
each := std.each
reduce := std.reduce
filter := std.filter
append := std.append
writeFile := std.writeFile

lower := str.lower
split := str.split
replace := str.replace
contains? := str.contains?
hasSuffix? := str.hasSuffix?
trim := str.trim

sortBy := quicksort.sortBy

serJSON := json.ser

Gray := ansi.Gray
Yellow := ansi.Yellow

now := util.now
error := util.error
trimWS := util.trimWS
truncate := util.truncate
formatTime := util.formatTime

markupText := markup.markupText
markupLen := markup.markupLen

Query := command.Query
Action := command.Action
parseQuery := command.parseQuery
formatQuery := command.formatQuery
parseCommand := command.parseCommand
formatCommand := command.formatCommand

Tab := char(9)
Newline := char(10)
MaxLine := 60
DefaultMaxResults := 25
MaxHistory := 100

` formatEntries is used to format wrapped text options output in the inc REPL.
Often, the CLI shows the user a list of entries from which the user can
select one or more things. When this happens, numbers and indentation must be
formatted correctly as well as line wrapping accounted for. This function
handles these tasks. `
formatEntries := entries => (
	maxDigitPlaces := len(string(len(entries))) + 2
	prefixPadding := cat(map(range(0, maxDigitPlaces, 1), n => ' '), '')

	entries :: {
		[] -> Gray('(no results)')
		_ -> (
			blocks := map(entries, (ent, i) => (
				ent := replace(ent, Newline, ' ')
				lines := reduce(split(ent, ' '), (lines, word) => (
					lastIdx := len(lines) - 1
					lastLine := lines.(lastIdx) :: {
						() -> lines.len(lines) := word
						_ -> markupLen(lastLine) + markupLen(word) < MaxLine :: {
							` should not `
							true -> lines.(lastIdx) := lastLine + ' ' + word
							` should wrap, potentially breaking word `
							_ -> (
								wordLines := map(range(0, markupLen(word), MaxLine), idx => (
									slice(word, idx, idx + MaxLine)
								))
								append(lines, wordLines)
							)
						}
					}
				), [])
				cat(map(lines, (line, lineIdx) => f('{{ 0 }} {{ 1 }}', [
					lineIdx :: {
						0 -> slice(prefixPadding, 0, maxDigitPlaces - len(string(i))) + Yellow(string(i))
						_ -> prefixPadding
					}
					trimWS(line)
				])), Newline)
			))
			cat(blocks, Newline)
		)
	}
)

` note database `
new := (initialDB, saveFilePath) => (
	` state `
	S := {
		db: initialDB
		choices: initialDB.notes
	}

	` helpers `

	searchNotes := keyword => filter(
		S.db.notes
		note => contains?(lower(note.content), lower(keyword))
	)

	getQueriedNotes := query => query.type :: {
		Query.List -> filter(map(query.values, i => S.choices.(i)), n => ~(n = ()))
		Query.Range -> slice(S.choices, query.min, query.max + 1)
		Query.Find -> query.keyword :: {
			'' -> []
			_ -> searchNotes(query.keyword)
		}
		_ -> error(f('unrecognized query {{ 0 }}', [query]))
	}

	` actions `

	persistAction := cb => (
		sortBy(S.db.notes, note => ~(note.updated))
		writeFile(saveFilePath, serJSON(S.db), res => res :: {
			true -> cb(())
			_ -> (
				error('failed to save')
				cb(())
			)
		})
	)

	addAction := (content, cb) => trimWS(content) :: {
		'' -> cb(())
		_ -> (
			S.db.notes.len(S.db.notes) := {
				created: now()
				updated: now()
				content: content
			}
			persistAction(cb)
		)
	}

	editAction := (query, content, cb) => (
		each(getQueriedNotes(query), note => (
			note.updated := now()
			note.content := trim(note.content, ' ') + Newline + content
		))
		persistAction(cb)
	)

	deleteAction := (query, cb) => (
		each(getQueriedNotes(query), note => (
			S.db.notes := filter(S.db.notes, n => ~(n = note))
		))
		persistAction(cb)
	)

	findAction := (keyword, cb) => (
		keyword := trimWS(keyword)
		matchedNotes := (keyword :: {
			'' -> S.db.notes
			_ -> searchNotes(keyword)
		})
		matchedNotes := slice(matchedNotes, 0, DefaultMaxResults)

		S.choices := matchedNotes

		` formatting `
		maxDigitPlaces := len(string(len(matchedNotes)))
		prefixPadding := cat(map(range(0, maxDigitPlaces, 1), n => ' '), '')

		noteEntries := map(matchedNotes, note => f('{{ 0 }} {{ 1 }}', [
			markupText(truncate(note.content), keyword)
			Gray(formatTime(note.updated))
		]))
		cb(formatEntries(noteEntries))
	)

	printAction := (query, cb) => cb(cat(map(
		getQueriedNotes(query)
		note => markupText(note.content, '')
	), Newline))

	historyAction := cb => (
		` formatting `
		maxDigitPlaces := len(string(len(S.db.events)))
		prefixPadding := cat(map(range(0, maxDigitPlaces, 1), n => ' '), '')

		historyEntries := map(S.db.events, cmd => f('{{ 0 }} {{ 1 }}', [
			markupText(formatCommand(cmd), '')
			Gray(formatTime(cmd.time))
		]))
		cb(formatEntries(historyEntries))
	)

	metaAction := cb => cb(cat([
		f('DB path: {{ 0 }}', [saveFilePath])
		f('Stats: {{ notes }} notes, {{ events }} events', {
			notes: len(S.db.notes)
			events: len(S.db.events)
		})
	], Newline))

	` main event loop `

	processInput := (line, cb) => (
		cmd := parseCommand(line)

		` add cmd to history if it's new `
		events := S.db.events
		formatCommand(events.(len(events) - 1)) :: {
			formatCommand(cmd) -> ()
			_ -> events.len(events) := cmd
		}
		len(S.db.events) > MaxHistory :: {
			true -> S.db.events := slice(S.db.events, len(S.db.events) - MaxHistory, MaxHistory)
		}
		` need to persist modifications to history `
		persistAction(() => ())

		cmd.type :: {
			Action.Create -> addAction(cmd.content, cb)
			Action.Edit -> editAction(cmd.query, cmd.content, cb)
			Action.Delete -> deleteAction(cmd.query, cb)
			Action.Find -> findAction(cmd.keyword, cb)
			Action.Print -> printAction(cmd.query, cb)
			Action.History -> historyAction(cb)
			Action.Meta -> metaAction(cb)
			_ -> (
				error(f('unrecognized command type "{{ 0 }}"', [cmd]))
				cb(())
			)
		}
	)

	performNextLoop := contentSoFar => (
		out('> ')
		scan(line => hasSuffix?(line, '\\') :: {
			true -> performNextLoop(contentSoFar + line + Newline)
			_ -> (
				processInput(contentSoFar + line, output => (
					type(output) :: {
						'string' -> log(output)
					}
					performNextLoop('')
				))
			)
		}
		)
	)

	{
		start: () => performNextLoop('')
		do: line => processInput(line, output => output :: {
			() -> ()
			_ -> log(output)
		})
	}
)

