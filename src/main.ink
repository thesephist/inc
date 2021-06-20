#!/usr/bin/env ink

std := load('../vendor/std')
str := load('../vendor/str')
quicksort := load('../vendor/quicksort')
json := load('../vendor/json')
ansi := load('../vendor/ansi')

log := std.log
f := std.format
scan := std.scan
slice := std.slice
cat := std.cat
map := std.map
every := std.every
filter := std.filter
readFile := std.readFile
writeFile := std.writeFile

digit? := str.digit?
index := str.index
split := str.split
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
DefaultMaxResults := 25
MaxHistory := 100
SaveFileName := 'inc.db.json'

Action := {
	Invalid: ~1
	Create: 0
	Edit: 1
	Delete: 2
	Find: 3
	Print: 4
	History: 5
	Pipeline: 6
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
		diff < 3600 -> f('{{ 0 }}m ago', [floor(diff / 60)])
		diff < 86400 -> f('{{ 0 }}h ago', [floor(diff / 3600)])
		diff < 86400 * 7 -> f('{{ 0 }}d ago', [floor(diff / 86400)])
		_ -> f('{{ 0 }}w ago', [floor(diff / 86400 / 7)])
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
			query: slice(line, 1, len(line))
		}
		_ -> (
			words := filter(split(line, ' '), word => len(word) > 0)
			` TODO: support choice lists and choice ranges
				- cmd 1 2 3 is like cmd 1, cmd 2, cmd 3
				- cmd 1-3 also does the same
				- cmd query operates on all notes matching the query `
			[words.0, numeric?(words.1)] :: {
				` shorthand, because muscle memory `
				['ls', _] -> {
					time: now()
					type: Action.Find
					query: ''
				}
				['rm', true] -> {
					time: now()
					type: Action.Delete
					choice: words.1
				}
				['show', true] -> {
					time: now()
					type: Action.Print
					choice: words.1
				}
				['add', true] -> {
					time: now()
					type: Action.Edit
					choice: words.1
					content: cat(slice(words, 2, len(words)), ' ')
				}
				['rm', _] -> {type: Action.Invalid}
				['show', _] -> {type: Action.Invalid}
				['add', _] -> {type: Action.Invalid}
				['history', _] -> {
					time: now()
					type: Action.History
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

formatCommand := cmd => cmd.type :: {
	Action.Create -> f('+ "{{ 0 }}"', [cmd.content])
	Action.Edit -> f('add {{ 0 }} "{{ 1 }}"', [cmd.choice, cmd.content])
	Action.Delete -> f('rm {{ 0 }}', [cmd.choice])
	Action.Find -> f('/{{ 0 }}', [cmd.query])
	Action.Print -> f('show {{ 0 }}', [cmd.choice])
	Action.History -> 'history'
	_ -> (
		error('unrecognized command type')
		cb(())
	)
}

` note database `
newDB := (initialDB, saveFilePath) => (
	` state `

	S := {
		db: initialDB
		choices: []
	}

	withChoiceNote := (choice, cb) => numeric?(choice) :: {
		false -> (
			error(f('{{ 0 }} is not a valid choice', [choice]))
			cb(())
		)
		_ -> chosen := S.choices.number(choice) :: {
			() -> (
				error(f('could not find choice {{ 0 }}', [choice]))
				cb(())
			)
			_ -> cb(chosen)
		}
	}

	` actions `

	persistAction := cb => writeFile(saveFilePath, serJSON(S.db), res => res :: {
		true -> cb(())
		_ -> (
			error('failed to save')
			cb(())
		)
	})

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

	editAction := (choice, content, cb) => withChoiceNote(choice, note => note :: {
		() -> cb(())
		_ -> (
			note.updated := now()
			note.content := trim(note.content, ' ') + ' ' + content
			persistAction(cb)
		)
	})

	printAction := (choice, cb) => withChoiceNote(choice, note => note :: {
		() -> cb(())
		_ -> cb(note.content)
	})

	findAction := (query, cb) => (
		matchedNotes := (trimWS(query) :: {
			'' -> S.db.notes
			_ -> filter(S.db.notes, note => contains?(note.content, query))
		})
		matchedNotes := slice(matchedNotes, 0, DefaultMaxResults)
		sortBy(matchedNotes, note => ~(note.updated))

		S.choices := matchedNotes
		noteLines := map(matchedNotes, (note, i) => f('  {{ 0 }} | {{ 1 }} {{ 2 }}', [
			Yellow(string(i))
			note.content
			Gray(formatTime(note.updated))
		]))
		noteLines :: {
			[] -> cb(Gray('(no results)'))
			_ -> cb(cat(noteLines, Newline))
		}
	)

	deleteAction := (choice, cb) => withChoiceNote(choice, chosen => chosen :: {
		() -> cb(())
		_ -> (
			S.db.notes := filter(S.db.notes, note => ~(note = chosen))
			persistAction(cb)
		)
	})

	getHistoryAction := cb => (
		historyLines := map(S.db.events, (cmd, i) => f('  {{ 0 }} | {{ 1 }} {{ 2 }}', [
			Yellow(string(i))
			formatCommand(cmd)
			Gray(formatTime(cmd.time))
		]))
		cb(cat(historyLines, Newline))
	)

	` main event loop `

	processInput := (line, cb) => (
		cmd := parseCommand(line)

		` history  management `
		S.db.events.len(S.db.events) := cmd
		len(S.db.events) > MaxHistory :: {
			true -> S.db.events := slice(S.db.events, len(S.db.events) - MaxHistory, MaxHistory)
		}

		cmd.type :: {
			Action.Create -> addAction(cmd.content, cb)
			Action.Edit -> editAction(cmd.choice, cmd.content, cb)
			Action.Delete -> deleteAction(cmd.choice, cb)
			Action.Find -> findAction(cmd.query, cb)
			Action.Print -> printAction(cmd.choice, cb)
			Action.History -> getHistoryAction(cb)
			_ -> (
				error('unrecognized command type')
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

