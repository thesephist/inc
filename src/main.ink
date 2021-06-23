#!/usr/bin/env ink

std := load('../vendor/std')
str := load('../vendor/str')
quicksort := load('../vendor/quicksort')
json := load('../vendor/json')
ansi := load('../vendor/ansi')

log := std.log
f := std.format
range := std.range
scan := std.scan
slice := std.slice
cat := std.cat
map := std.map
map := std.map
each := std.each
reduce := std.reduce
filter := std.filter
every := std.every
append := std.append
readFile := std.readFile
writeFile := std.writeFile

digit? := str.digit?
lower := str.lower
index := str.index
split := str.split
replace := str.replace
contains? := str.contains?
hasPrefix? := str.hasPrefix?
hasSuffix? := str.hasSuffix?
trim := str.trim

sortBy := quicksort.sortBy

serJSON := json.ser
deJSON := json.de

Gray := ansi.Gray
Yellow := ansi.Yellow

Tab := char(9)
Newline := char(10)
Editor := 'vim'
MaxLine := 60
DefaultMaxResults := 25
MaxHistory := 100
SaveFileName := 'inc.db.json'

Action := {
	Meta: ~1
	Create: 0
	Edit: 1
	Delete: 2
	Find: 3
	Print: 4
	History: 5
}

now := () => floor(time())

error := s => log('[error] ' + s)

numeric? := s => s :: {
	() -> false
	_ -> every(map(s, digit?))
}

trimWS := s => trim(trim(s, ' '), Tab)

` relative time format `
formatTime := time => (
	diff := now() - time
	true :: {
		diff < 60 -> 'now'
		diff < 3600 -> f('{{ 0 }}m', [floor(diff / 60)])
		diff < 86400 -> f('{{ 0 }}h', [floor(diff / 3600)])
		diff < 86400 * 7 -> f('{{ 0 }}d', [floor(diff / 86400)])
		_ -> f('{{ 0 }}w', [floor(diff / 86400 / 7)])
	}
)

Query := {
	List: 0
	Range: 1
	Find: 2
}

` Choice argument lists can take the forms
- cmd 1 2 3
- cmd 1-3 OR cmd 1 - 3
- cmd query `
parseQuery := text => (
	dashSpread := replace(text, '-', ' - ')
	parts := map(split(dashSpread, ' '), s => trim(s, ' '))

	numeric?(parts.0) & numeric?(parts.2) & parts = [_, '-', _] :: {
		true -> {
			type: Query.Range
			min: number(parts.0)
			max: number(parts.2)
		}
		_ -> every(map(parts, numeric?)) :: {
			true -> {
				type: Query.List
				values: map(parts, number)
			}
			_ -> {
				type: Query.Find
				keyword: trimWS(text)
			}
		}
	}
)

parseCommand := line => (
	line := trimWS(line)
	line.0 :: {
		'+' -> {
			time: now()
			type: Action.Create
			content: trimWS(slice(line, 1, len(line)))
		}
		'/' -> {
			time: now()
			type: Action.Find
			keyword: slice(line, 1, len(line))
		}
		_ -> (
			words := filter(split(line, ' '), word => len(word) > 0)
			words.0 :: {
				` shorthand, because muscle memory `
				'ls' -> {
					time: now()
					type: Action.Find
					keyword: ''
				}
				'rm' -> {
					time: now()
					type: Action.Delete
					query: parseQuery(cat(slice(words, 1, len(words)), ' '))
				}
				'show' -> {
					time: now()
					type: Action.Print
					query: parseQuery(cat(slice(words, 1, len(words)), ' '))
				}
				'add' -> {
					time: now()
					type: Action.Edit
					query: parseQuery(words.1)
					content: cat(slice(words, 2, len(words)), ' ')
				}
				'history' -> {
					time: now()
					type: Action.History
				}
				'meta' -> {
					time: now()
					type: Action.Meta
				}
				_ -> {
					` default action is to just type into the readline to add notes `
					time: now()
					type: Action.Create
					content: trimWS(line)
				}
			}
		)
	}
)

formatQuery := query => query.type :: {
	Query.List -> cat(map(query.values, string), ' ')
	Query.Range -> f('{{ min }} - {{ max }}', query)
	Query.Find -> f('{{ keyword }}', query)
	_ -> (
		error(f('unrecognized query type {{ 0 }}', [query]))
		''
	)
}

formatCommand := cmd => cmd.type :: {
	Action.Create -> f('+ "{{ 0 }}"', [cmd.content])
	Action.Edit -> f('add {{ 0 }} "{{ 1 }}"', [formatQuery(cmd.query), cmd.content])
	Action.Delete -> f('rm {{ 0 }}', [formatQuery(cmd.query)])
	Action.Find -> cmd.keyword :: {
		'' -> 'ls'
		_ -> f('/{{ 0 }}', [cmd.keyword])
	}
	Action.Print -> f('show {{ 0 }}', [formatQuery(cmd.query)])
	Action.History -> 'history'
	Action.Meta -> 'meta'
	_ -> (
		error(f('unrecognized command type {{ 0 }}', [cmd]))
		''
	)
}

formatEntries := entries => (
	maxDigitPlaces := len(string(len(entries))) + 2
	prefixPadding := cat(map(range(0, maxDigitPlaces, 1), n => ' '), '')

	entries :: {
		[] -> Gray('(no results)')
		_ -> (
			blocks := map(entries, (ent, i) => (
				lines := reduce(split(ent, ' '), (lines, word) => (
					lastIdx := len(lines) - 1
					lastLine := lines.(lastIdx) :: {
						() -> lines.len(lines) := word
						_ -> len(lastLine) + len(word) < MaxLine :: {
							` should not `
							true -> lines.(lastIdx) := lastLine + ' ' + word
							` should wrap, potentially breaking word `
							_ -> (
								wordLines := map(range(0, len(word), MaxLine), idx => (
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
newDB := (initialDB, saveFilePath) => (
	` state `

	S := {
		db: initialDB
		choices: initialDB.notes
	}

	searchNotes := keyword => filter(
		S.db.notes
		note => contains?(lower(note.content), lower(keyword))
	)

	getQueriedNotes := query => query.type :: {
		Query.List -> map(query.values, i => S.choices.(i))
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
			note.content := trim(note.content, ' ') + ' ' + content
		))
		persistAction(cb)
	)

	printAction := (query, cb) => cb(cat(map(
		getQueriedNotes(query)
		note => note.content
	), Newline))

	findAction := (keyword, cb) => (
		matchedNotes := (trimWS(keyword) :: {
			'' -> S.db.notes
			_ -> searchNotes(keyword)
		})
		matchedNotes := slice(matchedNotes, 0, DefaultMaxResults)

		S.choices := matchedNotes

		` formatting `
		maxDigitPlaces := len(string(len(matchedNotes)))
		prefixPadding := cat(map(range(0, maxDigitPlaces, 1), n => ' '), '')

		noteEntries := map(matchedNotes, note => f('{{ 0 }} {{ 1 }}', [
			note.content
			Gray(formatTime(note.updated))
		]))
		cb(formatEntries(noteEntries))
	)

	deleteAction := (query, cb) => (
		each(getQueriedNotes(query), note => (
			S.db.notes := filter(S.db.notes, n => ~(n = note))
		))
		persistAction(cb)
	)

	historyAction := cb => (
		` formatting `
		maxDigitPlaces := len(string(len(S.db.events)))
		prefixPadding := cat(map(range(0, maxDigitPlaces, 1), n => ' '), '')

		historyEntries := map(S.db.events, cmd => f('{{ 0 }} {{ 1 }}', [
			formatCommand(cmd)
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

` start main loop `

Args := args()

HomePath := env().HOME :: {
	() -> error('could not find home directory')
	'' -> error('could not find home directory')
	_ -> (
		` For development tasks, we use an Inc database local to this
		repository to keep track of tasks and ideas. This lets anyone override
		the location where Inc keeps its data stored. `
		saveFilePath := (env().'INC_DB_PATH' :: {
			() -> HomePath + '/' + SaveFileName
			_ -> env().'INC_DB_PATH' + '/' + SaveFileName
		})
		startWithInitialDB := initialDB => (
			inc := newDB(initialDB, saveFilePath)
			len(Args) :: {
				2 -> (inc.start)()
				_ -> (
					cmdArgs := cat(slice(Args, 2, len(Args)), ' ')
					(inc.do)(cmdArgs)
				)
			}
		)

		readFile(saveFilePath, file => file :: {
			() -> startWithInitialDB({
				` Note : {
					created: number (timestamp)
					updated: number (timestamp)
					content; string
				} `
				notes: []
				` Event : {
					type: 'create' | 'edit' | 'delete' | 'find'
					args: List<string>
				}`
				events: []
			})
			_ -> startWithInitialDB(deJSON(file))
		})
	)
}

