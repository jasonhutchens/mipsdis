/*
 * mipsdis is a simple javascript-based command line MIPS disassembler. The
 * core dispatch and decoding routines are autogenerated by mipsgen.
 *
 * usage: js mipsdis input.txt
 *
 * The expected input format is the first two columns from objdump:
 *
 *     hex_addr   hex_opcode
 *     80001678:  27bd0008
 *
 * The decoder will ignore any extra columns, and any lines not matching the
 * above format.
 *
 * The output format is similar to objdump output:
 *
 *     hex_addr   hex_opcode  asm
 *     80001678:  27bd0008    addiu  $29,$29,8
 *
 * This is not a fully featured disassembler, as it lacks quite a few
 * usability features, but it is sufficient for debugging and exercising the
 * code generator.
 *
 * See codegen/jsgen.rb for more information.
 */

/*
 * The field_xxx functions provide raw access to the bits denoted by code
 * letter in the 'opcode_bits' file.
 *
 * They are not responsible for interpretation, they just pick out the right
 * bits and shift them.
 *
 * note: we use >>> in javascript to treat these values as +ve integers
 */
function field_m(op) { return (op & 0xfc000000) >>> 26; }
function field_u(op) { return (op & 0x0000003f) >>> 0; }

function field_s(op) { return (op & 0x03e00000) >>> 21; }
function field_t(op) { return (op & 0x001f0000) >>> 16; }
function field_o(op) { return (op & 0x0000ffff) >>> 0; }
function field_i(op) { return (op & 0x0000ffff) >>> 0; }
function field_b(op) { return (op & 0x03e00000) >>> 21; }
function field_p(op) { return (op & 0x001f0000) >>> 16; }
function field_f(op) { return (op & 0x001f0000) >>> 16; }
function field_d(op) { return (op & 0x0000f800) >>> 11; }
function field_a(op) { return (op & 0x000007c0) >>> 6; }
function field_c(op) { return (op & 0x03ffffc0) >>> 6; }
function field_y(op) { return (op & 0x000007c0) >>> 6; }

function field_e(op) { return (op & 0x0000ffc0) >>> 6; }
function field_n(op) { return (op & 0x00000007) >>> 0; }
function field_x(op) { return (op & 0x03ffffff) >>> 0; }
function field_z(op) { return (op & 0x01ffffc0) >>> 6; }

/* Top 10 bits of syscode. */
function field_bc1(op) { return (op & 0x03ff0000) >>> 16; }

/* Bottom 10 bits of syscode. */
function field_bc2(op) { return (op & 0x0000ffc0) >>> 6; }

/* 
 * The getxxx functions interpret the results returned by field_xxx and any 
 * extra arithmetic or sign handling is done here.
 */
function getopcode(op) { return field_m(op); }
function getfunction(op) { return field_u(op); }

function getrt(op) { return field_t(op); }
function getrs(op) { return field_s(op); }
function getrd(op) { return field_d(op); }

// Compute the jump target address (used in j, jal).
function gettarget(pc, op)
{
    var x = field_x(op);

    var hibits = ((pc + 4) & (0xf0000000)) >>> 0;
    var lobits = x << 2;

    return (hibits | lobits) >>> 0;
}

// Compute the branch offset (used in beq, bne, etc).
function getbroff(pc, op)
{
    var o = field_o(op) << 2;
    var m = 1 << (18 - 1);
    var r = (o ^ m) - m;

    // this will be ok as long as pc is something sensible
    // may be weird around 0x00000000 / 0xffffffff
    // TODO - add a check / mask

    return (pc + 4) + r;
}

// Get the immediate field as a signed 16 bit quantity.
function getsimm(op) 
{
    var o = field_o(op);
    var m = 1 << (16 - 1);
    var r = (o ^ m) - m;

    return r;
}

function getimm(op) { return field_i(op); }
function getoffset(op) { return getsimm(op); }
function getbase(op) { return field_b(op); }
function getcacheop(op) { return field_p(op); }
function getprefhint(op) { return field_f(op); }
function getsa(op) { return field_a(op); }
function getbc1(op) { return field_bc1(op); }
function getbc2(op) { return field_bc2(op); }
function getsyscode(op) { return field_c(op); }
function getstype(op) { return field_y(op); }
function gettrapcode(op) { return field_e(op); }
function getsel(op) { return field_n(op); }
function getwaitcode(op) { return field_z(op); }

// Instruction validation functions.
// Returns true for OK, false otherwise.
function check_opcode(op, mask, value)
{
    // note (>>> 0) converts signed values to +ve unsigned
    // e.g. -1 becomes 4294967295 aka 0xffffffff
    return ((op & mask) >>> 0) === value;
}

function check_cl(rt, rd)
{
    return rt === rd;
}

function check_jalr(rs, rd)
{
    return rs !== rd;
}

// Handle illegal and reserved opcodes.
function decode_unusable(pc, op)
{
    return 'illegal'
}

function decode_reserved(pc, op)
{
    return 'illegal'
}

var ___fs = require("fs");

eval(___fs.readFileSync('disasm/js/sprintf.js', 'utf8'));
eval(___fs.readFileSync('disasm/js/mips_dispatch.js', 'utf8'));

function decode(pc, op)
{
    return decode_OPCODE(pc,op);
}

// Determines if a string is a valid address.
function is_addr(s)
{
    return s.match(/^[0-9a-fA-F]+:$/) !== null
}

// Determines if a string is a valid hexword.
function is_hexword(s)
{
    return s.match(/^[0-9a-fA-F]{8}$/) !== null
}

// Convert a string containing hex chars to a positive integer.
function hex_to_u32(s)
{
    return parseInt(s, 16)
}

function pp(o)
{
    console.log(JSON.stringify(o))
}

function get_input_data()
{
    return ___fs.readFileSync(process.argv[2], 'ascii').split("\n")
}

function main()
{
    var lines = get_input_data();

    for (var i = 0; i < lines.length; i++)
    {
        var l = lines[i];
        var toks = l.split(/[ \t\r]/);

        if (toks.length < 2)
            continue;

        var addrtok = toks[0];
        var optok = toks[1]

        if (!is_addr(addrtok) || !is_hexword(optok))
            continue;

        var address = hex_to_u32(addrtok);
        var opcode = hex_to_u32(optok);

        var out = decode(address, opcode);
        var line = sprintf("%08x:\t%08x\t%s", address, opcode, out);

        console.log(line);
    }
}

main()
