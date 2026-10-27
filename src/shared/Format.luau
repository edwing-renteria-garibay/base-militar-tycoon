-- Para mostrar el dinero bonito: 1234 -> "$1,234" y 2500000 -> "$2.5 M"

local Format = {}

local function commas(n: number): string
	local digits = tostring(math.floor(n))
	local reversed = (string.gsub(string.reverse(digits), "(%d%d%d)", "%1,"))
	local result = string.reverse(reversed)
	if string.sub(result, 1, 1) == "," then
		result = string.sub(result, 2)
	end
	return result
end

function Format.Money(n: number): string
	if n >= 1e9 then
		return string.format("$%.1f B", n / 1e9)
	elseif n >= 1e6 then
		return string.format("$%.1f M", n / 1e6)
	end
	return "$" .. commas(n)
end

return Format
