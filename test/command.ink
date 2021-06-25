command := load('../src/command')

Query := command.Query
Action := command.Action
parseQuery := command.parseQuery
formatQuery := command.formatQuery
parseCommand := command.parseCommand
formatCommand := command.formatCommand

run := (m, t) => (
	m('parseQuery')
	(
		t(
			'Empty query'
			parseQuery('')
			{
				type: Query.List
				values: []
			}
		)
		t(
			'Singe number'
			parseQuery('1')
			{
				type: Query.List
				values: [1]
			}
		)
		t(
			'Many numbers'
			parseQuery('1 3 5 2')
			{
				type: Query.List
				values: [1, 3, 5, 2]
			}
		)

		t(
			'Basic range without spaces'
			parseQuery('1-2')
			{
				type: Query.Range
				min: 1
				max: 2
			}
		)
		t(
			'Basic range with spaces'
			parseQuery(' 10 - 15   ')
			{
				type: Query.Range
				min: 10
				max: 15
			}
		)
		t(
			'Basic range with uneven spaces'
			parseQuery('10    -11')
			{
				type: Query.Range
				min: 10
				max: 11
			}
		)

		t(
			'Basic keyword query'
			parseQuery(' #keyword ')
			{
				type: Query.Find
				keyword: '#keyword'
			}
		)
		t(
			'Multiword keyword query'
			parseQuery(' april 1 2021 ')
			{
				type: Query.Find
				keyword: 'april 1 2021'
			}
		)
		t(
			'Multiword keyword query preserves whitespace'
			parseQuery('first   second third')
			{
				type: Query.Find
				keyword: 'first   second third'
			}
		)
		t(
			'Just an empty dash parses as a keyword'
			parseQuery(' -')
			{
				type: Query.Find
				keyword: '-'
			}
		)
		t(
			'Range with extra junk after numbers considered keyword'
			parseQuery('1 - 2 - 5')
			{
				type: Query.Find
				keyword: '1 - 2 - 5'
			}
		)
	)

	m('formatQuery')
	(
		t(
			'List of no numbers'
			formatQuery({
				type: Query.List
				values: []
			})
			''
		)
		t(
			'List of single number'
			formatQuery({
				type: Query.List
				values: [100]
			})
			'100'
		)
		t(
			'List of multiple numbers'
			formatQuery({
				type: Query.List
				values: [10, 9, 8, 7]
			})
			'10 9 8 7'
		)

		t(
			'Basic range'
			formatQuery({
				type: Query.Range
				min: 5
				max: 10
			})
			'5-10'
		)

		t(
			'Multiword find query'
			formatQuery({
				type: Query.Find
				keyword: '#keyword'
			})
			'#keyword'
		)
	)

	m('parseCommand -> formatCommand')
	(
		roundTrip := s => formatCommand(parseCommand(s))

		t(
			'Meta command'
			roundTrip('meta 1 2 3')
			'meta'
		)

		t(
			'Quick add with no command'
			roundTrip('hello world it\'s me')
			'+ hello world it\'s me'
		)
		t(
			'Proper add with +'
			roundTrip('+add this note')
			'+ add this note'
		)
		t(
			'Add note with + at the start'
			roundTrip('+ + is a plus sign!')
			'+ + is a plus sign!'
		)

		t(
			'Edit command with @ single note'
			roundTrip('@1 pound cakes')
			'@1 pound cakes'
		)
		t(
			'Edit command with a @ range query'
			roundTrip('@3-5 pound cakes')
			'@3-5 pound cakes'
		)
		t(
			'Edit command with a find keyword query'
			roundTrip('@#keyword death is unethical')
			'@#keyword death is unethical'
		)

		t(
			'Delete with no arguments'
			roundTrip('rm ')
			'rm '
		)
		t(
			'Delete command with multiple numbers'
			roundTrip('rm 0  1    2')
			'rm 0 1 2'
		)
		t(
			'Delete command with keyword query'
			roundTrip('rm    #hashtag')
			'rm #hashtag'
		)

		t(
			'Find command with some words'
			roundTrip('/some words')
			'/some words'
		)
		t(
			'Find command with prefixed space'
			roundTrip('/ some words')
			'/some words'
		)
		t(
			'Find command with hashtag'
			roundTrip('/#hashtag-me')
			'/#hashtag-me'
		)
		t(
			'Find command using # not /'
			roundTrip('#hashtag-me')
			'/#hashtag-me'
		)

		t(
			'Print command with multiple numbers'
			roundTrip('show 0 1 2')
			'show 0 1 2'
		)
		t(
			'Print command with find query'
			roundTrip('show #query like this')
			'show #query like this'
		)

		t(
			'History command'
			roundTrip('history cryonics 1 2 3')
			'history'
		)
	)
)
