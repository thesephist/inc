std := load('../vendor/std')
str := load('../vendor/str')
ansi := load('../vendor/ansi')

slice := std.slice

replace := str.replace

ansiStyle := ansi.style
Bold := ansi.BoldWhite
Blue := ansi.Blue
BackgroundRed := ansiStyle(ansi.Weight.Regular, ansi.Background.Red)

` Two kinds of syntax are marked up:
	- #hashtags are marked as blue
	- [bold] things are bolded
	- substrings that match the search query are red
They cannot overlap. `
markupText := (s, match) => (
	markupRest := (sofar, i) => i :: {
		len(s) -> sofar
		_ -> c := s.(i) :: {
			'#' -> (
				endOfHashtagIdx := (sub := j => s.(j) :: {
					() -> j
					' ' -> j
					_ -> sub(j + 1)
				})(i + 1)
				markupRest(
					sofar.len(sofar) := Blue(slice(s, i, endOfHashtagIdx))
					endOfHashtagIdx
				)
			)
			'[' -> (
				endOfBoldIdx := (sub := j => s.(j) :: {
					() -> j
					']' -> j + 1
					_ -> sub(j + 1)
				})(i + 1)
				markupRest(
					sofar.len(sofar) := Bold(slice(s, i, endOfBoldIdx))
					endOfBoldIdx
				)
			)
			_ -> markupRest(
				sofar.len(sofar) := c
				i + 1
			)
		}
	}
	result := markupRest('', 0)
	match :: {
		'' -> result
		_ -> replace(result, match, BackgroundRed(match))
	}
)

markupLen := s => (sub := (i, count) => i :: {
	len(s) -> count
	_ -> s.(i) :: {
		ansi.Esc -> (
			endOfEscSeq := (ssub := j => s.(j) :: {
				() -> j
				'm' -> j + 1
				_ -> ssub(j + 1)
			})(i)
			sub(endOfEscSeq, count)
		)
		_ -> sub(i + 1, count + 1)
	}
})(0, 0)

