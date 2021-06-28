#!/usr/bin/env ink

std := load('../vendor/std')
str := load('../vendor/str')
json := load('../vendor/json')
util := load('util')

slice := std.slice
cat := std.cat
filter := std.filter
readFile := std.readFile
hasPrefix? := str.hasPrefix?

deJSON := json.de

error := util.error

SaveFileName := 'inc.db.json'

newDB := load('db').new

` start main loop `

flag? := s => hasPrefix?(s, '--')

Args := filter(args(), s => ~flag?(s))
Flags := filter(args(), flag?)

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
			inc := newDB(initialDB, saveFilePath, {
				color?: filter(Flags, f => f = '--no-color') = []
			})
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

