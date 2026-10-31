// Native Markdown supports headings, lists and code. Normalize common math
// into readable Unicode; leave unsupported notation intact rather than
// silently changing its meaning. Fenced and inline code remain literal.
var SUPER = {"0":"⁰","1":"¹","2":"²","3":"³","4":"⁴","5":"⁵","6":"⁶","7":"⁷","8":"⁸","9":"⁹","+":"⁺","-":"⁻","=":"⁼","(":"⁽",")":"⁾","a":"ᵃ","b":"ᵇ","c":"ᶜ","d":"ᵈ","e":"ᵉ","i":"ⁱ","j":"ʲ","k":"ᵏ","m":"ᵐ","n":"ⁿ","o":"ᵒ","p":"ᵖ","r":"ʳ","s":"ˢ","t":"ᵗ","u":"ᵘ","v":"ᵛ","w":"ʷ","x":"ˣ","y":"ʸ","z":"ᶻ"};
var SUB = {"0":"₀","1":"₁","2":"₂","3":"₃","4":"₄","5":"₅","6":"₆","7":"₇","8":"₈","9":"₉","+":"₊","-":"₋","=":"₌","(":"₍",")":"₎","a":"ₐ","e":"ₑ","i":"ᵢ","j":"ⱼ","o":"ₒ","r":"ᵣ","u":"ᵤ","v":"ᵥ","x":"ₓ","n":"ₙ"};
function script(text, chars, fallback) {
	const s = text.trim();
	return s && Array.from(s).every(c => chars[c]) ? Array.from(s).map(c => chars[c]).join("") : fallback + "(" + s + ")";
}
function math(text) {
	return text.trim().replace(/\\(?:left|right)\b/g, "")
		.replace(/\\(?:text|mathrm|mathbf)\{([^{}]*)\}/g, "$1")
		.replace(/\\frac\{([^{}]*)\}\{([^{}]*)\}/g, "($1)/($2)")
		.replace(/\\sqrt\{([^{}]*)\}/g, "√($1)")
		.replace(/\\(times|cdot|div|pm|leq|geq|neq|approx|infty|pi|alpha|beta|theta)\b/g, (_, name) => ({times:"×",cdot:"·",div:"÷",pm:"±",leq:"≤",geq:"≥",neq:"≠",approx:"≈",infty:"∞",pi:"π",alpha:"α",beta:"β",theta:"θ"})[name])
		.replace(/\\[,;! ]/g, " ")
		.replace(/\^(?:\{([^{}]*)\}|([a-zA-Z0-9+-]))/g, (_, group, char) => script(group === undefined ? char : group, SUPER, "^"))
		.replace(/_(?:\{([^{}]*)\}|([a-zA-Z0-9+-]))/g, (_, group, char) => script(group === undefined ? char : group, SUB, "_"));
}
function markdown(text) {
	return String(text || "").split(/(```[\s\S]*?```|`[^`\n]*`)/g).map((part, i) => {
		if (i % 2) return part;
		return part.replace(/\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|\\\(([\s\S]+?)\\\)|\$([^$\n]+)\$/g, (raw, display, square, round, inline) => {
			const expr = display || square || round || inline;
			if (inline && !/[\\^_=]/.test(expr) && !/^[\d .()+*/-]+$/.test(expr)) return raw;
			return math(expr);
		}).replace(/!\[([^\]]*)\]\([^)]*\)/g, "$1") // No remote image fetches in replies.
			.replace(/</g, "&lt;").replace(/>/g, "&gt;");
	}).join("");
}
function safeLink(url) { return /^https?:\/\//i.test(String(url)); }
