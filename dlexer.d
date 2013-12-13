module dlexer;

import std.typecons;
import std.typetuple;
import std.array;
import std.stdio;
import std.algorithm;
import std.range;

import lexer;

private enum staticTokens = [
	",", ".", "..", "...", "/", "/=", "!", "!<", "!<=", "!<>", "!<>=", "!=",
	"!>", "!>=", "$", "%", "%=", "&", "&&", "&=", "(", ")", "*", "*=", "+", "++",
	"+=", "-", "--", "-=", ":", ";", "<", "<<", "<<=", "<=", "<>", "<>=", "=",
	"==", "=>", ">", ">=", ">>", ">>=", ">>>", ">>>=", "?", "@", "[", "]", "^",
	"^=", "^^", "^^=", "{", "|", "|=", "||", "}", "~", "~="
];

private enum pseudoTokens = [
	"\"", "`", "//", "/*", "/+", ".", "'", "0", "1", "2", "3", "4", "5", "6",
	"7", "8", "9", "#", "q\"", "q{", "r\"", "x\"", " ", "\t", "\r", "\n",
	"\u2028", "\u2029"
];

private enum possibleDefaultTokens = [
	"abstract", "alias", "align", "asm", "assert", "auto", "body", "bool",
	"break", "byte", "case", "cast", "catch", "cdouble", "cent", "cfloat",
	"char", "class", "const", "continue", "creal", "dchar", "debug", "default",
	"delegate", "delete", "deprecated", "do", "double", "else", "enum",
	"export", "extern", "false", "final", "finally", "float", "for", "foreach",
	"foreach_reverse", "function", "goto", "idouble", "if", "ifloat",
	"immutable", "import", "in", "inout", "int", "interface", "invariant",
	"ireal", "is", "lazy", "long", "macro", "mixin", "module", "new", "nothrow",
	"null", "out", "override", "package", "pragma", "private", "protected",
	"public", "pure", "real", "ref", "return", "scope", "shared", "short",
	"static", "struct", "super", "switch", "synchronized", "template", "this",
	"throw", "true", "try", "typedef", "typeid", "typeof", "ubyte", "ucent",
	"uint", "ulong", "union", "unittest", "ushort", "version", "void",
	"volatile", "wchar", "while", "with", "__DATE__", "__EOF__", "__FILE__",
	"__FUNCTION__", "__gshared", "__LINE__", "__MODULE__", "__parameters",
	"__PRETTY_FUNCTION__", "__TIME__", "__TIMESTAMP__", "__traits", "__vector",
	"__VENDOR__", "__VERSION__"
];

private enum dynamicTokens = [
	"specialTokenSequence", "comment", "identifier", "scriptLine",
	"whitespace", "doubleLiteral", "floatLiteral", "idoubleLiteral",
	"ifloatLiteral", "intLiteral", "longLiteral", "realLiteral",
	"irealLiteral", "uintLiteral", "ulongLiteral", "characterLiteral",
	"dstringLiteral", "stringLiteral", "wstringLiteral"
];

struct DLexer(R)
{
	import std.conv;
	
	mixin Lexer!(R, isSeparating, lexIdentifier, staticTokens, dynamicTokens,
		pseudoTokens, possibleDefaultTokens);
		
	this(R range)
	{
		registerPostProcess!"\""(&lexStringLiteral!RangeType);
		registerPostProcess!"`"(&lexWysiwygString!RangeType);
		registerPostProcess!"//"(&lexSlashSlashComment!RangeType);
		registerPostProcess!"/*"(&lexSlashStarComment!RangeType);
		registerPostProcess!"/+"(&lexSlashPlusComment!RangeType);
		registerPostProcess!"."(&lexDot!RangeType);
		registerPostProcess!"'"(&lexCharacterLiteral!RangeType);
		registerPostProcess!"0"(&lexNumber!RangeType);
		registerPostProcess!"1"(&lexNumber!RangeType);
		registerPostProcess!"2"(&lexNumber!RangeType);
		registerPostProcess!"3"(&lexNumber!RangeType);
		registerPostProcess!"4"(&lexNumber!RangeType);
		registerPostProcess!"5"(&lexNumber!RangeType);
		registerPostProcess!"6"(&lexNumber!RangeType);
		registerPostProcess!"7"(&lexNumber!RangeType);
		registerPostProcess!"8"(&lexNumber!RangeType);
		registerPostProcess!"9"(&lexNumber!RangeType);
		registerPostProcess!"#"(&lexNumber!RangeType);
		registerPostProcess!"q\""(&lexDelimitedString!RangeType);
		registerPostProcess!"q{"(&lexTokenString!RangeType);
		registerPostProcess!"r\""(&lexWysiwygString!RangeType);
		registerPostProcess!"x\""(&lexHexString!RangeType);
		registerPostProcess!" "(&lexWhitespace!RangeType);
		registerPostProcess!"\t"(&lexWhitespace!RangeType);
		registerPostProcess!"\r"(&lexWhitespace!RangeType);
		registerPostProcess!"\n"(&lexWhitespace!RangeType);
		registerPostProcess!"\u2028"(&lexLongNewline!RangeType);
		registerPostProcess!"\u2029"(&lexLongNewline!RangeType);
		this.range = RangeType(range);
		popFront();
	}
	
	

	static bool isWhitespace(LR)(LR range)
	{
		switch (range.front)
		{
		case ' ':
		case '\r':
		case '\n':
		case '\t':
			return true;
		case 0xe2:
			if (!range.canPeek(2))
				return false;
			return range.peek() == 0x80
				&& (range.peek(2) == 0xa8 || range.peek(2) == 0xa9);
		default:
			return false;
		}
	}

	static void popFrontWhitespaceAware(LR)(ref LR range)
	{
		switch (range.front)
		{
		case '\r':
			range.popFront();
			if (!range.empty && range.front == '\n')
			{
				range.popFront();
				range.incrementLine();
			}
			else
				range.incrementLine();
			return;
		case '\n':
			range.popFront();
			range.incrementLine();	
			return;
		case 0xe2:
			if (range.canPeek(2) && range.peek() == 0x80
				&& (range.peek(2) == 0xa8 || range.peek(2) == 0xa9))
			{
				range.popFront();
				range.popFront();
				range.popFront();
				range.incrementLine();
				return;
			}
			else
			{
				range.popFront();
				return;
			}
		default:
			range.popFront();
			return;
		}
	}

	Token lexWhitespace(LR)(ref LR range)
	{
		range.mark();
		loop: while (!range.empty)
		{
			switch (range.front)
			{
			case '\r':
				range.popFront();
				if (!range.empty && range.front == '\n')
					range.popFront();
				range.incrementLine();
				break;
			case '\n':
				range.popFront();
				range.incrementLine();
				break;
			case ' ':
			case '\t':
				range.popFront();
				break;
			case 0xe2:
				if (!range.canPeek(2))
					break loop;
				if (range.peek() != 0x80)
					break loop;
				if (range.peek(2) == 0xa8 || range.peek(2) == 0xa9)
				{
					range.popFront();
					range.popFront();
					range.popFront();
					range.incrementLine();
					break;
				}
				break loop;
			default:
				break loop;
			}
		}
		return Token(tok!"whitespace", cast(string) range.getMarked(), range.line,
			range.column, range.index);
	}

	Token lexNumber(LR)(ref LR range)
	{
		range.mark();
		if (range.front == '0')
		{
			switch (range.peek())
			{
			case 'x':
			case 'X':
				range.popFront();
				range.popFront();
				return lexHex(range);
			case 'b':
			case 'B':
				range.popFront();
				range.popFront();
				return lexBinary(range);
			default:
				return lexDecimal(range);
			}
		}
		else
			return lexDecimal(range);
	}

	Token lexHex(LR)(ref LR range)
	{
		IDType type = tok!"intLiteral";
		bool foundDot;
		hexLoop: while (!range.empty)
		{
			switch (range.front)
			{
			case 'a': .. case 'f':
			case 'A': .. case 'F':
			case '0': .. case '9':
			case '_':
				range.popFront();
				break;
			case 'u':
			case 'U':
				lexIntSuffix(range, type);
				break hexLoop;
			case 'i':
				if (foundDot)
					lexFloatSuffix(range, type);
				break hexLoop;
			case 'L':
				if (foundDot)
				{
					lexFloatSuffix(range, type);
					break hexLoop;
				}
				else
				{
					lexIntSuffix(range, type);
					break hexLoop;
				}
			case 'p':
			case 'P':
				lexExponent(range, type);
				break hexLoop;
			case '.':
				if (foundDot)
					break hexLoop;
				if (range.canPeek() && range.peek() == '.')
					break hexLoop;
				range.popFront();
				foundDot = true;
				type = tok!"doubleLiteral";
				break;
			default:
				break hexLoop;
			}
		}
		return Token(type, cast(string) range.getMarked(), range.line, range.column,
			range.index);
	}

	Token lexBinary(LR)(ref LR range)
	{
		IDType type = tok!"intLiteral";
		binaryLoop: while (!range.empty)
		{
			switch (range.front)
			{
			case '0':
			case '1':
			case '_':
				range.popFront();
				break;
			case 'u':
			case 'U':
			case 'L':
				lexIntSuffix(range, type);
				break binaryLoop;
			default:
				break binaryLoop;
			}
		}
		return Token(type, cast(string) range.getMarked(), range.line, range.column,
			range.index);
	}

	Token lexDecimal(LR)(ref LR range)
	{
		bool foundDot = range.front == '.';
		auto type = tok!"intLiteral";
		if (foundDot)
		{
			range.popFront();
			type = tok!"doubleLiteral";
		}

		decimalLoop: while (!range.empty)
		{
			switch (range.front)
			{
			case '0': .. case '9':
			case '_':
				range.popFront();
				break;
			case 'u':
			case 'U':
				if (!foundDot)
					lexIntSuffix(range, type);
				break decimalLoop;
			case 'i':
				lexFloatSuffix(range, type);
				break decimalLoop;
			case 'L':
				if (foundDot)
					lexFloatSuffix(range, type);
				else
					lexIntSuffix(range, type);
				break decimalLoop;
			case 'f':
			case 'F':
				lexFloatSuffix(range, type);
				break decimalLoop;
			case 'e':
			case 'E':
				lexExponent(range, type);
				break decimalLoop;
			case '.':
				if (foundDot)
					break decimalLoop;
				if (range.canPeek() && range.peek() == '.')
					break decimalLoop;
				else
				{
					// The following bit of silliness tries to tell the
					// difference between "int dot identifier" and
					// "double identifier".
					if (range.canPeek())
					{
						switch (range.peek())
						{
						case '0': .. case '9':
							goto doubleLiteral;
						default:
							break decimalLoop;
						}
					}
					else
					{
					doubleLiteral:
						range.popFront();
						foundDot = true;
						type = tok!"doubleLiteral";
					}
				}
				break;
			default:
				break decimalLoop;
			}
		}
		return Token(type, cast(string) range.getMarked(), range.line, range.column,
			range.index);
	}

	static void lexIntSuffix(R)(ref R range, ref IDType type)
	{
		bool secondPass;
		if (range.front == 'u' || range.front == 'U')
		{
	U:
			if (type == tok!"intLiteral")
				type = tok!"uintLiteral";
			else
				type = tok!"ulongLiteral";
			range.popFront();
			if (secondPass)
				return;
			if (range.front == 'L' || range.front == 'l')
				goto L;
			return;
		}
		if (range.front == 'L' || range.front == 'l')
		{
	L:
			if (type == tok!"uintLiteral")
				type = tok!"ulongLiteral";
			else
				type = tok!"longLiteral";
			range.popFront();
			if (range.front == 'U' || range.front == 'u')
			{
				secondPass = true;
				goto U;
			}
			return;
		}
	}

	static void lexFloatSuffix(R)(ref R range, ref IDType type)
	{
		switch (range.front)
		{
		case 'L':
			range.popFront();
			type = tok!"doubleLiteral";
			break;
		case 'f':
		case 'F':
			range.popFront();
			type = tok!"floatLiteral";
			break;
		default:
			break;
		}
		if (!range.empty && range.front == 'i')
		{
			range.popFront();
			if (type == tok!"floatLiteral")
				type = tok!"ifloatLiteral";
			else
				type = tok!"idoubleLiteral";
		}
	}

	static void lexExponent(R)(ref R range, ref IDType type)
	{
		range.popFront();
		bool foundSign = false;
		bool foundDigit = false;
		while (!range.empty)
		{
			switch (range.front)
			{
			case '-':
			case '+':
				if (foundSign)
				{
					if (!foundDigit)
					writeln("Expected an exponent");
					return;
				}
				foundSign = true;
				range.popFront();
				break;
			case '0': .. case '9':
			case '_':
				foundDigit = true;
				range.popFront();
				break;
			case 'L':
			case 'f':
			case 'F':
			case 'i':
				lexFloatSuffix(range, type);
				return;
			default:
				if (!foundDigit)
					writeln("Expected an exponent");
				return;
			}
		}
	}


	Token lexSpecialTokenSequence(LR)(ref LR range)
	{
		assert (false, "Not implemented");
	}

	Token lexSlashStarComment(LR)(ref LR range)
	{
		range.mark();
		IDType type = tok!"comment";
		range.popFront();
		range.popFront();
		while (!range.empty)
		{
			if (range.front == '*')
			{
				range.popFront();
				if (!range.empty && range.front == '/')
				{
					range.popFront();
					break;
				}
			}
			else
				popFrontWhitespaceAware(range);
		}
		return Token(type, cast(string) range.getMarked(), range.line, range.column,
			range.index);
	}
	
	Token lexSlashSlashComment(LR)(ref LR range)
	{
		range.mark();
		IDType type = tok!"comment";
		range.popFront();
		range.popFront();
		while (!range.empty)
		{
			if (range.front == '\r' || range.front == '\n')
				break;
			range.popFront();
		}
		return Token(type, cast(string) range.getMarked(), range.line, range.column,
			range.index);
	}
	
	Token lexSlashPlusComment(LR)(ref LR range)
	{
		range.mark();
		IDType type = tok!"comment";
		range.popFront();
		range.popFront();
		int depth = 1;
		while (depth > 0 && !range.empty)
		{
			if (range.front == '+')
			{
				range.popFront();
				if (!range.empty && range.front == '/')
				{
					range.popFront();
					depth--;
				}
			}
			else if (range.front == '/')
			{
				range.popFront();
				if (!range.empty && range.front == '+')
				{
					range.popFront();
					depth++;
				}
			}
			else
				popFrontWhitespaceAware(range);
		}
		return Token(type, cast(string) range.getMarked(), range.line, range.column,
			range.index);
	}

	Token lexStringLiteral(LR)(ref LR range)
	{
		range.mark();
		range.popFront();
		while (true)
		{
			if (range.empty)
			{
				writeln("Error: unterminated string literal");
				return Token();
			}
			else if (range.front == '"')
			{
				range.popFront();
				break;
			}
			else if (range.front == '\\')
			{
				lexEscapeSequence(range);
			}
			else
				range.popFront();
		}
		IDType type = tok!"stringLiteral";
		lexStringSuffix(range, type);
		return Token(type, cast(string) range.getMarked(), range.line, range.column,
			range.index);
	}

	Token lexWysiwygString(LR)(ref LR range)
	{
		range.mark();
		IDType type = tok!"stringLiteral";
		bool backtick = range.front == '`';
		if (backtick)
		{
			range.popFront();
			while (true)
			{
				if (range.empty)
					goto error;
				else if (range.front == '`')
				{
					range.popFront();
					break;
				}
				else
					popFrontWhitespaceAware(range);
			}
		}
		else
		{
			range.popFront();
			if (range.empty)
				goto error;
			range.popFront();
			while (true)
			{
				if (range.empty)
					goto error;
				else if (range.front == '"')
				{
					range.popFront();
					break;
				}
				else
					popFrontWhitespaceAware(range);
			}
		}
		lexStringSuffix(range, type);
		return Token(type, cast(string) range.getMarked(), range.line, range.column,
			range.index);
	error:
		writeln("Error: unterminated string literal");
		return Token();
	}

	static void lexStringSuffix(R)(ref R range, ref IDType type)
	{
		if (range.empty)
			type = tok!"stringLiteral";
		else
		{
			switch (range.front)
			{
			case 'w': range.popFront(); type = tok!"wstringLiteral"; break;
			case 'd': range.popFront(); type = tok!"dstringLiteral"; break;
			case 'c': range.popFront(); type = tok!"stringLiteral"; break;
			default: type = tok!"stringLiteral"; break;
			}
		}
	}

	Token lexDelimitedString(LR)(ref LR range)
	{
		range.mark();
		range.popFront();
		range.popFront();
		ElementEncodingType!R open;
		ElementEncodingType!R close;
		switch (range.front)
		{
		case '<':
			open = '<';
			close = '>';
			range.popFront();
			return lexNormalDelimitedString!LR(range, open, close);
		case '{':
			open = '{';
			close = '}';
			range.popFront();
			return lexNormalDelimitedString!LR(range, open, close);
		case '[':
			open = '[';
			close = ']';
			range.popFront();
			return lexNormalDelimitedString!LR(range, open, close);
		case '(':
			open = '(';
			close = ')';
			range.popFront();
			return lexNormalDelimitedString!LR(range, open, close);
		default:
			return lexHeredocString(range);
		}
	}

	Token lexNormalDelimitedString(LR)(ref LR range,
		ElementEncodingType!LR open,
		ElementEncodingType!LR close)
	{
		int depth = 1;
		while (!range.empty && depth > 0)
		{
			if (range.front == open)
			{
				depth++;
				range.popFront();
			}
			else if (range.front == close)
			{
				depth--;
				range.popFront();
				if (depth <= 0)
				{
					if (range.front == '"')
						range.popFront();
					else
					{
						writeln("Error: \" expected to end delimited string literal");
						return Token(tok!"");
					}
				}
			}
			else
				popFrontWhitespaceAware(range);
		}
		IDType type = tok!"stringLiteral";
		lexStringSuffix(range, type);
		return Token(type, cast(string) range.getMarked(), range.line, range.column, range.index);
	}

	Token lexHeredocString(LR)(ref LR range)
	{
		assert (false, "unimplemented");
	}

	Token lexTokenString(LR)(ref LR range)
	{
		range.popFront();
		range.popFront();
		auto app = appender!string();
		app.put("q{");
		int depth = 1;
		while (depth > 0 && !empty)
		{
			popFront();
			auto t = front();
			if (t.text is null)
				app.put(str(t.type));
			else
				app.put(t.text);
			if (t.type == tok!"}")
				depth--;
			else if (t.type == tok!"{")
				depth++;
		}
		IDType type = tok!"stringLiteral";
		lexStringSuffix(range, type);
		return Token(type, app.data, range.line, range.column, range.index);
	}

	Token lexHexString(LR)(ref LR range)
	{
		range.mark();
		range.popFront();
		range.popFront();
		
		loop: while (true)
		{
			if (range.empty)
			{
				writeln("Error: unterminated hex string literal");
				return Token();
			}
			else if (isWhitespace(range))
				popFrontWhitespaceAware(range);
			else switch (range.front)
			{
			case '0': .. case '9':
			case 'F': .. case 'F':
			case 'a': .. case 'f':
				range.popFront();
				break;
			case '"':
				range.popFront();
				break loop;
			default:
				writeln("Error: invalid character in hex string");
				return Token();
			}
		}
		
		IDType type = tok!"stringLiteral";
		lexStringSuffix(range, type);
		return Token(type, cast(string) range.getMarked(), range.line, range.column,
			range.index);
	}

	static bool lexEscapeSequence(LR)(ref LR range)
	{
		range.popFront();
		if (range.empty)
		{
			writeln("Error: non-terminated character escape sequence.");
			return false;
		}
		switch (range.front)
		{
		case '\'':
		case '"':
		case '?':
		case '\\':
		case '0':
		case 'a':
		case 'b':
		case 'f':
		case 'n':
		case 'r':
		case 't':
		case 'v':
			range.popFront();
			break;
		case 'x':
			// TODO
			range.popFront();
			break;
		case '1': .. case '7':
			for (size_t i = 0; i < 3 && !range.empty && range.front >= '0' && range.front <= '7'; i++)
				range.popFront();
			break;
		case 'u':
			range.popFront();
			foreach (i; 0 .. 4)
			{
				if (range.empty)
				{
					writeln("Error: at least 4 hex digits expected.");
					return false;
				}
				switch (range.front)
				{
				case '0': .. case '9':
				case 'a': .. case 'f':
				case 'A': .. case 'F':
					range.popFront();
					break;
				default:
					writeln("Error: at least 4 hex digits expected.");	
					return false;
				}
			}
			break;
		case 'U':
			range.popFront();
			foreach (i; 0 .. 8)
			{
				if (range.empty)
				{
					writeln("Error: at least 8 hex digits expected.");
					return false;
				}
				switch (range.front)
				{
				case '0': .. case '9':
				case 'a': .. case 'f':
				case 'A': .. case 'F':
					range.popFront();
					break;
				default:
					writeln("Error: at least 8 hex digits expected.");
					return false;
				}
			}
			break;
		default:
			while (true)
			{
				if (range.empty)
				{
					writeln("Error: non-terminated character escape sequence.");
					return false;
				}
				if (range.front == ';')
					break;
				else
					range.popFront();
			}
		}
		return true;
	}

	Token lexCharacterLiteral(LR)(ref LR range)
	{
		range.mark();
		range.popFront();
		if (range.front == '\\')
		{
			lexEscapeSequence(range);
			goto close;
		}
		else if (range.front == '\'')
		{
			range.popFront();
			return Token(tok!"characterLiteral", cast(string) range.getMarked(),
				range.line, range.column, range.index);
		}
		else if (range.front & 0x80)
		{
			while (range.front & 0x80)
				range.popFront();
			goto close;
		}
		else
		{
			popFrontWhitespaceAware(range);
			goto close;
		}
	close:
		if (range.front == '\'')
		{
			range.popFront();
			return Token(tok!"characterLiteral", cast(string) range.getMarked(),
				range.line, range.column, range.index);
		}
		else
		{
			writeln("Error: Expected ' to end character literal ", cast(char) range.front);
			return Token();
		}
	}

	Token lexIdentifier(LR)(ref LR range)
	{
		range.mark();
		while (!range.empty && !isSeparating(range.front))
		{
			range.popFront();
		}
		return Token(tok!"identifier", cast(string) range.getMarked(), range.index,
			range.line, range.column);
	}

	Token lexDot(LR)(ref LR range)
	{
		if (!range.canPeek)
		{
			range.popFront();
			return Token(tok!".", null, range.line, range.column, range.index);
		}
		switch (range.peek())
		{
		case '0': .. case '9':
			return lexNumber(range);
		case '.':
			range.popFront();
			range.popFront();
			if (range.front == '.')
			{
				range.popFront();
				return Token(tok!"...", null, range.line, range.column, range.index);
			}
			else
				return Token(tok!"..", null, range.line, range.column, range.index);
		default:
			range.popFront();
			return Token(tok!".", null, range.line, range.column, range.index);
		}
	}

	Token lexLongNewline(LR)(ref LR range)
	{
		range.mark();
		range.popFront();
		range.popFront();
		range.popFront();
		range.incrementLine();
		return Token(tok!"whitespace", cast(string) range.getMarked(), range.line,
			range.column, range.index);
	}

	static bool isSeparating(C)(C c)
	{
		if (c <= 0x2f) return true;
		if (c >= ':' && c <= '@') return true;
		if (c >= '[' && c <= '^') return true;
		if (c >= '{' && c <= '~') return true;
		if (c == '`') return true;
		return false;
	}
}
