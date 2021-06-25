ansi := load('../vendor/ansi')

markup := load('../src/markup')
markupText := markup.markupText
markupLen := markup.markupLen

ansiStyle := ansi.style
Bold := ansi.BoldWhite
Blue := ansi.Blue
BackgroundRed := ansiStyle(ansi.Weight.Regular, ansi.Background.Red)

run := (m, t) => (
	m('markupText')
	(
		t(
			'Empty string'
			markupText('', '')
			''
		)
		t(
			'Empty string with a keyword'
			markupText('', 'keyword!')
			''
		)
		t(
			'Plain string'
			markupText('This is a plain string!', '')
			'This is a plain string!'
		)

		t(
			'Empty hashtag'
			markupText('abc # def', '')
			'abc ' + Blue('#') + ' def'
		)
		t(
			'Hashtag by itself'
			markupText('#hashtag', '')
			Blue('#hashtag')
		)
		t(
			'Hashtag with dash inside'
			markupText('#hashtag-string', '')
			Blue('#hashtag-string')
		)
		t(
			'Hashtag with other text'
			markupText('This is a #hashtag with #other text', '')
			'This is a ' + Blue('#hashtag') + ' with ' + Blue('#other') + ' text'
		)

		t(
			'Bracketed bold by itself'
			markupText('[i am bold]', '')
			Bold('[i am bold]')
		)
		t(
			'Bracketed bold, unclosed'
			markupText('[i am bold', '')
			Bold('[i am bold')
		)
		t(
			'Multiple bracketed bold in a row'
			markupText('first [second] third [fourth] [fifth', '')
			'first ' + Bold('[second]') + ' third ' + Bold('[fourth]') + ' ' + Bold('[fifth')
		)

		t(
			'Mixed hashtag and brackets'
			markupText('#first thing [today #here] is to #fix[things]', '')
			Blue('#first') + ' thing ' + Bold('[today #here]') + ' is to ' + Blue('#fix[things]')
		)

		t(
			'Match string matches whole text'
			markupText('match-me', 'match-me')
			BackgroundRed('match-me')
		)
		t(
			'Match string matches start and end of text'
			markupText('key hold key', 'key')
			BackgroundRed('key') + ' hold ' + BackgroundRed('key')
		)
		t(
			'Match string highlights inside words'
			markupText('abcdefg', 'cde')
			'ab' + BackgroundRed('cde') + 'fg'
		)
		t(
			'Multi-word match'
			markupText('Even if fault Bitcoin has worse fault tolerance', 'fault tolerance')
			'Even if fault Bitcoin has worse ' + BackgroundRed('fault tolerance')
		)
		t(
			'Match string highlights the same match twice'
			markupText('A sentence with a keyword that is key to this whole okey.', 'key')
			'A sentence with a ' + BackgroundRed('key') + 'word that is ' + BackgroundRed('key') + ' to this whole o' + BackgroundRed('key') + '.'
		)
		t(
			'If there are multiple matches that overlap, only highlight the first'
			markupText('aaaaa', 'aa')
			BackgroundRed('aa') + BackgroundRed('aa') + 'a'
		)

		t(
			'Match overlapping with hashtag'
			markupText('xxx #yyy zzz', 'yyy')
			'xxx ' + Blue('#' + BackgroundRed('yyy')) + ' zzz'
		)
		t(
			'Match overlapping with bold'
			markupText('xxx [yyy] zzz', 'yyy')
			'xxx ' + Bold('[' + BackgroundRed('yyy') + ']') + ' zzz'
		)
	)

	m('markupLen')
	(
		t(
			'Empty string'
			markupLen('')
			0
		)

		t(
			'Plain unmarked string'
			markupLen('hello world!')
			12
		)
		t(
			'One highlight'
			markupLen('hello ' + Bold('world!'))
			12
		)
		t(
			'Overlapping highlights'
			markupLen('hello ' + Bold(Blue('world') + '!'))
			12
		)
	)
)
