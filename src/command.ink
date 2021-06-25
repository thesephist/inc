std := load('../vendor/std')
str := load('../vendor/str')
quicksort := load('../vendor/quicksort')
json := load('../vendor/json')
ansi := load('../vendor/ansi')
util := load('util')

f := std.format
slice := std.slice
cat := std.cat
map := std.map
filter := std.filter
every := std.every

split := str.split
replace := str.replace
trim := str.trim

now := util.now
numeric? := util.numeric?
trimWS := util.trimWS

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
	parts := filter(map(split(dashSpread, ' '), s => trim(s, ' ')), s => ~(s = ''))

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

Action := {
	Meta: ~1
	Create: 0
	Edit: 1
	Delete: 2
	Find: 3
	Print: 4
	History: 5
}

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
			keyword: trimWS(slice(line, 1, len(line)))
		}
		'@' -> {
			time: now()
			type: Action.Edit
			query: (
				firstWord := split(line, ' ').0
				restOfFirstWord := slice(firstWord, 1, len(firstWord))
				parseQuery(restOfFirstWord)
			)
			content: (
				words := split(line, ' ')
				cat(slice(words, 1, len(words)), ' ')
			)
		}
		` typing a hashtag by itself performs a search for that hashtag. For
		example, #todo is equivalent to /#todo. This means the user cannot add
		notes beginning with hashtags, but that seems like a fine limitation
		because they can work around with the + command. `
		'#' -> {
			time: now()
			type: Action.Find
			keyword: line
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
	Query.Range -> f('{{ min }}-{{ max }}', query)
	Query.Find -> f('{{ keyword }}', query)
	_ -> (
		error(f('unrecognized query type {{ 0 }}', [query]))
		''
	)
}

formatCommand := cmd => cmd.type :: {
	Action.Create -> f('+ {{ 0 }}', [cmd.content])
	Action.Edit -> f('@{{ 0 }} {{ 1 }}', [formatQuery(cmd.query), cmd.content])
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

