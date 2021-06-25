std := load('../vendor/std')
str := load('../vendor/str')

log := std.log
f := std.format
map := std.map
slice := std.slice
every := std.every

digit? := str.digit?
trim := str.trim

Tab := char(9)
MaxTrim := 280 ` Tweet sized `

now := () => floor(time())

error := s => log('[error] ' + s)

` checks if a string contains only numeric characters, and thus can safely be
converted to a number using number() `
numeric? := s => s :: {
	() -> false
	_ -> every(map(s, digit?))
}

` trims whitespace, namely spaces and tabs `
trimWS := s => trim(trim(s, ' '), Tab)

truncate := s => len(s) > MaxTrim :: {
	true -> slice(s, 0, MaxTrim) + '...'
	_ -> s
}

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

