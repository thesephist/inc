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
every := std.every
append := std.append
readFile := std.readFile
writeFile := std.writeFile

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

now := util.now
error := util.error
trimWS := util.trimWS
truncate := util.truncate
formatTime := util.formatTime

Query := command.Query
Action := command.Action
parseQuery := command.parseQuery
formatQuery := command.formatQuery
parseCommand := command.parseCommand
formatCommand := command.formatCommand

markupText := markup.markupText
markupLen := markup.markupLen

Tab := char(9)
Newline := char(10)
MaxLine := 60
DefaultMaxResults := 25
SaveFileName := 'inc.db.json'

newDB := load('db').new

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

