runMarkupTests := load('markup').run
runCommandTests := load('command').run

s := (load('../vendor/suite').suite)(
	'Inc test suite'
)

runMarkupTests(s.mark, s.test)
runCommandTests(s.mark, s.test)

(s.end)()

